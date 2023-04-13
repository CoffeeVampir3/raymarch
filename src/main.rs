//! A compute shader that simulates Conway's Game of Life.
//!
//! Compute shaders use the GPU for computing arbitrary information, that may be independent of what
//! is rendered to the screen.

use bevy::{
    prelude::*,
    render::{
        extract_resource::{ExtractResource, ExtractResourcePlugin},
        render_asset::RenderAssets,
        render_graph::{self, RenderGraph},
        render_resource::*,
        renderer::{RenderContext, RenderDevice, RenderQueue},
        Render, RenderApp, RenderSet,
    },
    window::{WindowPlugin, WindowResized},
};
use std::{borrow::{Cow}};

const SIZE: (u32, u32) = (1280, 720);
const WORKGROUP_SIZE: u32 = 8;

fn main() {
    App::new()
        .insert_resource(ClearColor(Color::BLACK))
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                // uncomment for unthrottled FPS
                // present_mode: bevy::window::PresentMode::AutoNoVsync,
                ..default()
            }),
            ..default()
        }))
        .add_plugin(GameOfLifeComputePlugin)
        .add_systems(Startup, setup)
        .add_systems(Update, (on_window_resize, handle_input))
        .run();
}

fn on_window_resize(
    mut resize_ev: EventReader<WindowResized>,
    mut sprites: Query<&mut Sprite>,
) {
    for ev in resize_ev.iter() {
        let mut b = sprites.get_single_mut().unwrap();
        let res = Vec2::new(ev.width, ev.height);
        b.custom_size = Some(res);
    }
}

fn handle_input(
    mut goli: ResMut<PlayerData>,
    keys: Res<Input<KeyCode>>,
) {
    let mut move_dir = Vec2::ZERO;
    for key in keys.get_just_pressed() {
        match key {
            KeyCode::W => move_dir = Vec2::new(0.0, -1.0),
            KeyCode::S => move_dir = Vec2::new(0.0, 1.0),
            KeyCode::A => move_dir = Vec2::new(-1.0, 0.0),
            KeyCode::D => move_dir = Vec2::new(1.0, 0.0),
            _ => {}
        }
        println!("{:?}", move_dir);
    }
    let prev = *goli.player_position.get();
    goli.player_position.set(prev + move_dir * 0.1);
}

fn setup(mut commands: Commands, mut images: ResMut<Assets<Image>>, render_device: Res<RenderDevice>,) {
    let mut image = Image::new_fill(
        Extent3d {
            width: SIZE.0,
            height: SIZE.1,
            depth_or_array_layers: 1,
        },
        TextureDimension::D2,
        &[0, 0, 0, 255],
        TextureFormat::Rgba8Unorm,
    );
    image.texture_descriptor.usage =
        TextureUsages::COPY_DST | TextureUsages::STORAGE_BINDING | TextureUsages::TEXTURE_BINDING;
    let image = images.add(image);

    let time_buffer = render_device.create_buffer_with_data(&BufferInitDescriptor 
        { 
            label: None, 
            contents: bytemuck::bytes_of(&0_0f32), 
            usage: BufferUsages::UNIFORM | BufferUsages::COPY_DST }
        );

    let player_pos = encase::UniformBuffer::from(Vec2::ZERO);

    commands.spawn(SpriteBundle {
        sprite: Sprite {
            custom_size: Some(Vec2::new(SIZE.0 as f32, SIZE.1 as f32)),
            ..default()
        },
        texture: image.clone(),
        ..default()
    });
    commands.spawn(Camera2dBundle::default());

    commands.insert_resource(GameOfLifeImage{image, time:time_buffer});
    commands.insert_resource(PlayerData{player_position: player_pos})
}

pub struct GameOfLifeComputePlugin;

impl Plugin for GameOfLifeComputePlugin {
    fn build(&self, app: &mut App) {
        // Extract the game of life image resource from the main world into the render world
        // for operation on by the compute shader and display on the sprite.
        app.add_plugin(ExtractResourcePlugin::<GameOfLifeImage>::default());
        let render_app = app.sub_app_mut(RenderApp);
        render_app
            .init_resource::<GameOfLifePipeline>()
            .add_systems(Render, queue_bind_group.in_set(RenderSet::Queue));

        let mut render_graph = render_app.world.resource_mut::<RenderGraph>();
        render_graph.add_node("raymarcher", GameOfLifeNode::default());
        render_graph.add_node_edge(
            "raymarcher",
            bevy::render::main_graph::node::CAMERA_DRIVER,
        );
    }
}

#[derive(Resource, Clone, ExtractResource)]
struct GameOfLifeImage{
    image: Handle<Image>,
    time: Buffer,
}

#[derive(Resource)]
struct PlayerData {
    player_position: UniformBuffer<Vec2>,
}

#[derive(Resource)]
struct GameOfLifeImageBindGroup(BindGroup);

fn queue_bind_group(
    mut commands: Commands,
    pipeline: Res<GameOfLifePipeline>,
    gpu_images: Res<RenderAssets<Image>>,
    game_of_life_image: Res<GameOfLifeImage>,
    mut player_data: ResMut<PlayerData>,
    time: Res<Time>,
    render_device: Res<RenderDevice>,
    rq: Res<RenderQueue>,
) {
    let view = &gpu_images[&game_of_life_image.image];
    rq.write_buffer(&game_of_life_image.time, 0, bevy::core::cast_slice(&[time.elapsed_seconds_wrapped()]));

    player_data.player_position.write_buffer(&render_device, &rq);

    //render_device.map_buffer(buffer, MapMode::Write, callback);
    let bind_group = render_device.create_bind_group(&BindGroupDescriptor {
        label: None,
        layout: &pipeline.texture_bind_group_layout,
        entries: &[BindGroupEntry {
            binding: 0,
            resource: BindingResource::TextureView(&view.texture_view),
        },
        BindGroupEntry {
            binding: 1,
            resource: BindingResource::Buffer(game_of_life_image.time.as_entire_buffer_binding()),
        },
        BindGroupEntry {
            binding: 2,
            resource: player_data.player_position.binding().unwrap(),
        }],
    });
    commands.insert_resource(GameOfLifeImageBindGroup(bind_group));
}

#[derive(Resource)]
pub struct GameOfLifePipeline {
    texture_bind_group_layout: BindGroupLayout,
    init_pipeline: CachedComputePipelineId,
    update_pipeline: CachedComputePipelineId,
}

impl FromWorld for GameOfLifePipeline {
    fn from_world(world: &mut World) -> Self {
        let texture_bind_group_layout =
            world
                .resource::<RenderDevice>()
                .create_bind_group_layout(&BindGroupLayoutDescriptor {
                    label: None,
                    entries: &[BindGroupLayoutEntry {
                        binding: 0,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::StorageTexture {
                            access: StorageTextureAccess::ReadWrite,
                            format: TextureFormat::Rgba8Unorm,
                            view_dimension: TextureViewDimension::D2,
                        },
                        count: None,
                    },
                    BindGroupLayoutEntry {
                        binding: 1,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Buffer { 
                            ty: BufferBindingType::Uniform, 
                            has_dynamic_offset: false, 
                            min_binding_size: None },
                        count: None,
                    },
                    BindGroupLayoutEntry {
                        binding: 2,
                        visibility: ShaderStages::COMPUTE,
                        ty: BindingType::Buffer { 
                            ty: BufferBindingType::Uniform, 
                            has_dynamic_offset: false, 
                            min_binding_size: None },
                        count: None,
                    }],
                });
        let shader = world
            .resource::<AssetServer>()
            .load("shaders/raymarcher.wgsl");
        let pipeline_cache = world.resource::<PipelineCache>();
        let init_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
            label: None,
            layout: vec![texture_bind_group_layout.clone()],
            push_constant_ranges: Vec::new(),
            shader: shader.clone(),
            shader_defs: vec![],
            entry_point: Cow::from("init"),
        });
        let update_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
            label: None,
            layout: vec![texture_bind_group_layout.clone()],
            push_constant_ranges: Vec::new(),
            shader,
            shader_defs: vec![],
            entry_point: Cow::from("update"),
        });

        GameOfLifePipeline {
            texture_bind_group_layout,
            init_pipeline,
            update_pipeline,
        }
    }
}

enum GameOfLifeState {
    Loading,
    Init,
    Update,
}

struct GameOfLifeNode {
    state: GameOfLifeState,
}

impl Default for GameOfLifeNode {
    fn default() -> Self {
        Self {
            state: GameOfLifeState::Loading,
        }
    }
}

impl render_graph::Node for GameOfLifeNode {
    fn update(&mut self, world: &mut World) {
        let pipeline = world.resource::<GameOfLifePipeline>();
        let pipeline_cache = world.resource::<PipelineCache>();

        // if the corresponding pipeline has loaded, transition to the next stage
        match self.state {
            GameOfLifeState::Loading => {
                if let CachedPipelineState::Ok(_) =
                    pipeline_cache.get_compute_pipeline_state(pipeline.init_pipeline)
                {
                    self.state = GameOfLifeState::Init;
                }
            }
            GameOfLifeState::Init => {
                if let CachedPipelineState::Ok(_) =
                    pipeline_cache.get_compute_pipeline_state(pipeline.update_pipeline)
                {
                    self.state = GameOfLifeState::Update;
                }
            }
            GameOfLifeState::Update => {}
        }
    }

    fn run(
        &self,
        _graph: &mut render_graph::RenderGraphContext,
        render_context: &mut RenderContext,
        world: &World,
    ) -> Result<(), render_graph::NodeRunError> {
    let texture_bind_group = &world.resource::<GameOfLifeImageBindGroup>().0;
    let pipeline_cache = world.resource::<PipelineCache>();
    let pipeline = world.resource::<GameOfLifePipeline>();

    let mut pass = render_context
        .command_encoder()
        .begin_compute_pass(&ComputePassDescriptor::default());

    pass.set_bind_group(0, texture_bind_group, &[]);

    // select the pipeline based on the current state
    match self.state {
        GameOfLifeState::Loading => {}
        GameOfLifeState::Init => {
            let init_pipeline = pipeline_cache
                .get_compute_pipeline(pipeline.init_pipeline)
                .unwrap();
            pass.set_pipeline(init_pipeline);
            pass.dispatch_workgroups(SIZE.0 / WORKGROUP_SIZE, SIZE.1 / WORKGROUP_SIZE, 1);
        }
        GameOfLifeState::Update => {
            let update_pipeline = pipeline_cache
                .get_compute_pipeline(pipeline.update_pipeline)
                .unwrap();
            pass.set_pipeline(update_pipeline);
            pass.dispatch_workgroups(SIZE.0 / WORKGROUP_SIZE, SIZE.1 / WORKGROUP_SIZE, 1);
        }
    }

    Ok(())
    }
}