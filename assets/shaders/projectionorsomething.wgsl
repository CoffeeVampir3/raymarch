@group(0) @binding(0)
var texture: texture_storage_2d<rgba8unorm, read_write>;

@compute @workgroup_size(8, 8, 1)
fn init(@builtin(global_invocation_id) invocation_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let color = vec4(0.0);

    textureStore(texture, location, color);
}

fn circle_sdf(p: vec2<f32>, r: f32) -> f32 
{
    return length(p)-r;
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let res = vec2<f32>(1280., 720.);

    let coord = vec2<f32>(invocation_id.xy);

    let p: vec2<f32> = (2.0*coord-res.xy)/res.y;

    let d = circle_sdf(p, .5);

    var color: vec3<f32>;

    if d > 0.0 {
        color = vec3(1.0);
    } else {
        color = vec3(0.0);
    }

    storageBarrier();

    textureStore(texture, location, vec4<f32>(color, 1.0));
}