@group(0) @binding(0)
var texture: texture_storage_2d<rgba8unorm, read_write>;

fn hash(value: u32) -> u32 {
    var state = value;
    state = state ^ 2747636419u;
    state = state * 2654435769u;
    state = state ^ state >> 16u;
    state = state * 2654435769u;
    state = state ^ state >> 16u;
    state = state * 2654435769u;
    return state;
}

fn randomFloat(value: u32) -> f32 {
    return f32(hash(value)) / 4294967295.0;
}

fn get_dist(p: vec3<f32>) -> f32 {
    let s = vec4(0., 1., 6., 1.);

    let dist = length(p - s.xyz) - s.w;
    let pd = p.y;

    let final_dist = min(dist, pd);
    return final_dist;
}

fn dda_ray_march(origin: vec3<f32>, direction: vec3<f32>) -> f32 {
    let epsilon = 0.01;
    var t_max = vec3<f32>(0.0);
    var t_delta = vec3<f32>(0.0);
    var step = vec3<i32>(0);

    for (var i = 0; i < 3; i++) {
        if (direction[i] > 0.0) {
            step[i] = 1;
            t_max[i] = (ceil(origin[i]) - origin[i]) / direction[i];
            t_delta[i] = 1.0 / abs(direction[i]);
        } else {
            step[i] = -1;
            t_max[i] = (floor(origin[i]) - origin[i]) / direction[i];
            t_delta[i] = 1.0 / abs(direction[i]);
        }
    }

    var current_position = origin;
    var dO = 0.0;

    for (var i = 0; i < 100; i++) {
        let dS = get_dist(current_position);

        if (dO > 100.0 || dS < epsilon) {
            break;
        }

        let axis = min(min(t_max.x, t_max.y), t_max.z);
        let step_distance = (axis - dO) * 1.001;

        if (axis == t_max.x) {
            t_max.x += t_delta.x;
        } else if (axis == t_max.y) {
            t_max.y += t_delta.y;
        } else {
            t_max.z += t_delta.z;
        }

        current_position += step_distance * direction;
        dO += step_distance;
    }

    return dO;
}

fn ray_march(origin: vec3<f32>, direction: vec3<f32>) -> f32 {
    var dO = 0.;
    for(var i = 0; i < 100; i++) {
        let p: vec3<f32> = origin + direction * dO;
        let dS: f32 = get_dist(p);
        dO = dO + dS;

        if(dO > 100. || dS < 0.01) {
            break;
        }
    }
    return dO;
}

@compute @workgroup_size(8, 8, 1)
fn init(@builtin(global_invocation_id) invocation_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
    let color = vec4(0.0);

    textureStore(texture, location, color);
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let d = get_dist(p);
    let e: vec2<f32> = vec2(0.01, 0.);
    let n: vec3<f32> = d - vec3<f32>(
                    get_dist(p-e.xyy), 
                    get_dist(p-e.yxy), 
                    get_dist(p-e.yyx));

    return normalize(n);
}

fn calclight(p: vec3<f32>) -> vec3<f32> {
    var lp = vec3(0., 5., 6.);
    let l = normalize(lp-p);
    let n = get_normal(p);

    let dif = dot(n, l);
    return vec3(dif);
}

@compute @workgroup_size(8, 8, 1)
fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    let res = vec2<f32>(1280., 720.);

    var uv = (vec2<f32>(invocation_id.xy) - .5 * res.xy)/res.y;
    uv.y = -uv.y;

    let ray_origin = vec3(0., 1., 0.);
    let ray_direction = normalize(vec3<f32>(uv.x, uv.y, 1.));

    let ray_dist = dda_ray_march(ray_origin, ray_direction);

    let p = ray_origin + ray_direction * ray_dist;
    let diffuse = calclight(p);

    let color = vec3<f32>(diffuse);

    storageBarrier();

    textureStore(texture, location, vec4<f32>(color, 1.0));
}