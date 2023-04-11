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
    let s = circle_sdf(p, f2(0.5), 0.2);
    let s2 = circle_sdf(p, f2(0.2), 0.2);
    let s3 = circle_sdf(p, f2(-0.5), .83);
    let s4 = circle_sdf(p, f2(-0.5, 0.5), 0.2);

    let dist = min(min(min(s, s2), s3), s4);
    
    return dist;
}

fn scene_index(p: f2) -> i32 {
    let s = circle_sdf(p, f2(0.5), 0.2);
    let s2 = circle_sdf(p, f2(0.2), 0.2);
    let s3 = circle_sdf(p, f2(-0.5), .83);
    let s4 = circle_sdf(p, f2(-0.5, 0.5), 0.2);

    let dist = min(min(min(s, s2), s3), s4);

    if dist == s {
        return 0;
    } else if dist == s2 {
        return 1;
    } else if dist == s3 {
        return 2;
    } else if dist == s4 {
        return 3;
    }
    return -1;
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let res = f2(1280., 720.);

    let coord = vec2<f32>(invocation_id.xy);
    let origin = f2(sin(time)/1.67, cos(time*3.9)/2.1);
    let aspect = res.x/res.y;

    var pixel_point: vec2<f32> = f2((2.0*coord-res.xy)/res.y);

    let dir = normalize(pixel_point - origin);
    let max_len = length(pixel_point - origin);

    var d0 = 0.0;
    var k = 0.0;
    for(var i = 0; i < 100; i++) {
        let p = origin + d0 * dir;
        k = scene_sdf(p);
        d0 += k;
        if k < 0.001 {
            break;
        }
    }

    var color: f3;
    let residual = abs(max_len - d0);
    if(residual < 0.01) {
        color = f3(sin(residual*100.));
    } else {
        color = f3(0.1375);
    }

    let a = scene_index(origin);
    let b = scene_index(pixel_point);
    if (a == b && a != -1 && scene_sdf(pixel_point) < 0.0 && scene_sdf(origin) < 0.0) {
        let n = abs(scene_sdf(pixel_point));
        color = f3(n);
    }

    if (max_len < 0.04) {
        color = f3(1.0);
    }

    storageBarrier();

    textureStore(texture, location, vec4<f32>(color, 1.0));
}