@group(0) @binding(0)
var texture: texture_storage_2d<rgba8unorm, read_write>;
@group(0) @binding(1)
var<uniform> time: f32;

type f2 = vec2<f32>;
type f3 = vec3<f32>;
type i2 = vec2<i32>;


@compute @workgroup_size(8, 8, 1)
fn init(@builtin(global_invocation_id) invocation_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let color = vec4(0.0);

    textureStore(texture, location, color);
}

fn circle_sdf(p: f2, center: f2, r: f32) -> f32 
{
    return length(p-center)-r;
}

fn scene_sdf(p: vec2<f32>) -> f32 {
    let s = circle_sdf(p, f2(0.1), 0.05);

    let dist = s;
    
    return dist;
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let res = f2(1280., 720.);

    let coord = vec2<f32>(invocation_id.xy);
    let origin = f2(0.0, 0.0);
    let aspect = res.x/res.y;

    var pixel_point: vec2<f32> = f2((2.0*coord.x - res.x) / res.x, (2.0 * coord.y - res.y) / res.y);
    pixel_point.x *= aspect;

    let dir = normalize(pixel_point - origin);
    let max_len = length(pixel_point - origin);

    var color: f3;

    var d0 = 0.0;
    var min_d = 0.0;
    for (var i = 0; i < 100; i++) {
        let point = origin + dir * d0;
        min_d = scene_sdf(point);
        d0 = d0 + min_d;
        if min_d < 0.001 || d0 > max_len {
            break;
        }
    }

    let is_hit = d0 < .1;
    if is_hit {
        color = f3(0.0);
    } else {
        color = f3(0.3);
    }

    storageBarrier();

    textureStore(texture, location, vec4<f32>(d0, d0, d0, 1.0));
}