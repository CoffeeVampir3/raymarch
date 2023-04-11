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

fn circle_sdf(p: vec2<f32>, r: f32) -> f32 
{
    return length(p)-r;
}

fn mandelbulb(c: vec2<f32>, max_iterations: u32) -> f32 {
    var z = vec2<f32>(0.0, 0.0);
    var iterations: u32 = 0u;

    while (iterations < max_iterations) {
        let x_sq = z.x * z.x;
        let y_sq = z.y * z.y;

        if (x_sq + y_sq > 4.0) {
            break;
        }

        z = vec2<f32>(x_sq - y_sq + c.x, 2.0 * z.x * z.y + c.y);
        iterations = iterations + 1u;
    }

    return f32(iterations) / f32(max_iterations);
}

fn julia(z: vec2<f32>, c: vec2<f32>, max_iterations: u32) -> f32 {
    var iterations: u32 = 0u;

    while (iterations < max_iterations) {
        let x_sq = z.x * z.x;
        let y_sq = z.y * z.y;

        if (x_sq + y_sq > 4.0) {
            break;
        }

        let z = vec2<f32>(x_sq - y_sq + c.x, 2.0 * z.x * z.y + c.y);
        iterations = iterations + 1u;
    }

    return f32(iterations) / f32(max_iterations);
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let res = f2(1280., 720.);

    let aspect = res.x/res.y;
    let coord = f2(invocation_id.xy) / res.xy * f2(aspect, 1.0);
    let origin = f2(.5f * aspect, .5f);

    let coord2 = (f2(invocation_id.xy) / res.xy * f2(aspect, 1.0) * 2.0 - f2(aspect, 1.0)) * 2.0;
    let coord3 = (f2(invocation_id.xy) / res.xy * f2(aspect, 1.0) * 2.0 - f2(aspect, 1.0)) * fract(time);
    var coord4 = (f2(invocation_id.xy) / res.xy * f2(aspect, 1.0) * 2.0 - f2(aspect, 1.0)) + fract(time);

    let rotx = cos(time);
    let roty = sin(time);
    let rotated = f2(
        coord4.x * rotx - coord4.y * roty,
        coord4.x * roty + coord4.y * rotx
    );

    let rotated2 = f2(
        coord3.x * rotx - coord3.y * roty,
        coord3.x * roty + coord3.y * rotx
    );

    let rotated3 = f2(
        coord2.x * rotx - coord2.y * roty,
        coord2.x * roty + coord2.y * rotx
    );

    let julia_constant = vec2<f32>( -0.202420806884766, 0.39527333577474);

    //let distance = circle_sdf(coord - origin, 0.3);
    let distance = mandelbulb(rotated3, 77u - u32(50f*sin(time*11f)));
    let distance2 = mandelbulb(rotated2, 77u - u32(50f*cos(time*7f)));
    let distance3 = mandelbulb(coord2, 400u);
    let direction = normalize(coord - origin);

    //let color: f32 = select(1.0, 0.0, distance < 0.0);

    let dira = sin(time) * direction.x;
    let dirb = cos(time*direction.y);

    let c = select(0.0, 1.0, distance > 0.5);
    let l = select(0.0, 1.0, distance > 0.5 && distance < .9);
    let k = select(0.0, 1.0, distance2 > 0.5 && distance2 < .9);
    let v = select(0.0, 1.0, distance3 > 0.5 && distance3 < .9);

    storageBarrier();

    textureStore(texture, location, vec4<f32>(distance3, 0f, 0f, .1));
}