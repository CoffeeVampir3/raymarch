@group(0) @binding(0)
var texture: texture_storage_2d<rgba8unorm, read_write>;
@group(0) @binding(1)
var<uniform> time: f32;
@group(0) @binding(2)
var<uniform> player_input: vec2<f32>;

type f2 = vec2<f32>;
type f3 = vec3<f32>;
type i2 = vec2<i32>;

var<private> shapes: array<f3,8> = array<f3,8>
    (
    vec3<f32>(0.5, 0.5, 0.2), 
    vec3<f32>(0.2, 0.2, 0.2), 
    vec3<f32>(-0.5, -0.5, 0.2), 
    vec3<f32>(-0.5, 0.5, 0.2),
    vec3<f32>(0.5, -0.5, 0.2), 
    vec3<f32>(-0.2, -0.3, 0.3), 
    vec3<f32>(-0.5, -0.7, 0.3), 
    vec3<f32>(0.5, -0.7, 0.2)
    );

var<private> shape_index: u32 = 8u;

@compute @workgroup_size(8, 8, 1)
fn init(@builtin(global_invocation_id) invocation_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let color = vec4(0.0);

    textureStore(texture, location, color);
}

fn circle_sdf(p: f2, c: f3) -> f32 
{
    return length(p-c.xy)-c.z;
}

fn min_df(p: f2) -> f32 {
    var min: f32 = 999999999.9;
    for(var i = 0u; i < shape_index; i++) {
        let a = shapes[i];
        min = min(min, circle_sdf(p, a));
    }
    return min;
}

fn scene_sdf(p: vec2<f32>) -> f32 {
    return min_df(p);
}

fn scene_index(p: f2) -> i32 {
    let min = min_df(p);

    for(var i = 0; i < i32(shape_index); i++) {
        let a = shapes[i];
        if(min == circle_sdf(p, a)) {
            return i;
        }
    }

    return -1;
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let res = f2(1280., 720.);

    let coord = vec2<f32>(invocation_id.xy);
    let aspect = res.x/res.y;

    var pixel_point: vec2<f32> = f2((2.0*coord-res.xy)/res.y);

    let dir = normalize(pixel_point - player_input);
    let max_len = length(pixel_point - player_input);

    var d0 = 0.0;
    var k = 0.0;
    for(var i = 0; i < 100; i++) {
        let p = player_input + d0 * dir;
        k = scene_sdf(p);
        d0 += k;
        if k < 0.001 {
            break;
        }
    }

    var color: f3;

    if (max_len < 0.04) {
        color = f3(1.0);
    }

    storageBarrier();

    textureStore(texture, location, vec4<f32>(color, 1.0));
}