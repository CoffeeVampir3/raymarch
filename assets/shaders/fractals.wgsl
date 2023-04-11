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

fn burning_ship(z: vec2<f32>, max_iterations: u32) -> f32 {
    var c = z;
    var iterations: u32 = 0u;

    while (iterations < max_iterations) {
        let x_sq = z.x * z.x;
        let y_sq = z.y * z.y;
        let magnitude_sq = x_sq + y_sq;

        if (magnitude_sq > 4.0) {
            break;
        }

        let z = vec2<f32>(x_sq - y_sq + c.x, abs(2.0 * z.x * z.y) + c.y);
        iterations = iterations + 1u;
    }

    return f32(iterations) / f32(max_iterations);
}

fn fractal(c: vec2<f32>, iter: u32, q: f32) -> f32 {
    var z = vec2<f32>(0.0, 0.0);
    
    for (var i = 0u; i < iter; i = i + 1u) {
        z = vec2<f32>(z.x * z.x - z.y * z.y, abs(2.0 * z.x * z.y)) + c;
        if (dot(z, z) > q) {
            return f32(i) / f32(iter);
        }
    }
    
    return 0.0;
}

@compute @workgroup_size(16, 16, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let res = f2(1280., 720.);
    let aspect = res.x / res.y;
    let coord = f2(invocation_id.xy) / res.xy * f2(aspect, 1.0);

    let c = (coord - vec2<f32>(.9)) * 1.65;
    let fractal_value = fractal(c, 4u + u32(32f*sin(time/21.7f)), 2.0+4.0*sin(time/1f));
    
    let color = vec3<f32>(fractal_value, fractal_value, fractal_value);

    let v = select(0.0, 1.0, fractal_value > 0.3);

    storageBarrier();

    textureStore(texture, location, vec4<f32>(f3(color), 1.0));
}