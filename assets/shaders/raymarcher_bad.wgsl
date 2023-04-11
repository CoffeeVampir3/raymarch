// /* @group(0) @binding(0)
// var texture: texture_storage_2d<rgba8unorm, read_write>;

// // Grid dimensions
// const GRID_SIZE: i32 = 16;

// // Grid cell size
// const CELL_SIZE: f32 = 1.0;

// // Create a 3D array representing the voxel grid
// var<private> grid: array<array<array<f32, GRID_SIZE>, GRID_SIZE>, GRID_SIZE>;

// // Update the grid with the signed distance values for each sphere
// fn update_grid(center: vec3<f32>, radius: f32) {
//     let grid_center: vec3<f32> = (center / CELL_SIZE).xyz;

//     let min_idx: vec3<i32> = max(vec3<i32>(0), vec3<i32>(floor(grid_center - radius / CELL_SIZE).xyz));
//     let max_idx: vec3<i32> = min(vec3<i32>(GRID_SIZE - 1), vec3<i32>(ceil(grid_center + radius / CELL_SIZE).xyz));

//     for (var x = min_idx.x; x <= max_idx.x; x = x + 1) {
//         for (var y = min_idx.y; y <= max_idx.y; y = y + 1) {
//             for (var z = min_idx.z; z <= max_idx.z; z = z + 1) {
//                 let cell_position = vec3<f32>(f32(x), f32(y), f32(z)) * CELL_SIZE;
//                 let dist = length(cell_position - center) - radius;
//                 let idx = vec3<i32>(i32(x), i32(y), i32(z));
//                 grid[idx.x][idx.y][idx.z] = min(grid[idx.x][idx.y][idx.z], dist);
//             }
//         }
//     }
// }

// // Modify the get_dist function to use the voxel grid
// fn get_dist(p: vec3<f32>) -> f32 {
//     let idx = (p / CELL_SIZE).xyz;
//     let uidx = vec3<i32>(i32(idx.x), i32(idx.y), i32(idx.z));

//     if (uidx.x >= GRID_SIZE || uidx.y >= GRID_SIZE || uidx.z >= GRID_SIZE) {
//         return 1000.0;
//     }

//     return grid[uidx.x][uidx.y][uidx.z];
// }

// fn dda_ray_march(origin: vec3<f32>, direction: vec3<f32>) -> f32 {
//     let epsilon = 0.01;
//     var t_max = vec3<f32>(0.0);
//     var t_delta = vec3<f32>(0.0);
//     var step = vec3<i32>(0);

//     for (var i = 0; i < 3; i++) {
//         if (direction[i] > 0.0) {
//             step[i] = 1;
//             t_max[i] = (ceil(origin[i] / CELL_SIZE) * CELL_SIZE - origin[i]) / direction[i];
//             t_delta[i] = CELL_SIZE / abs(direction[i]);
//         } else {
//             step[i] = -1;
//             t_max[i] = (floor(origin[i] / CELL_SIZE) * CELL_SIZE - origin[i]) / direction[i];
//             t_delta[i] = CELL_SIZE / abs(direction[i]);
//         }
//     }

//     var current_position = origin;
//     var dO = 0.0;

//     for (var i = 0; i < 100; i++) {
//         let dS = get_dist(current_position);

//         if (dO > 100.0 || dS < epsilon) {
//             break;
//         }

//         let axis = min(min(t_max.x, t_max.y), t_max.z);
//         let step_distance = (axis - dO) * (1.0 + epsilon);
//         dO = dO + step_distance;
//         current_position = origin + direction * dO;

//         if (direction.x < 0.0) {
//             t_max.x = t_max.x + t_delta.x;
//         }
//         if (direction.y < 0.0) {
//             t_max.y = t_max.y + t_delta.y;
//         }
//         if (direction.z < 0.0) {
//             t_max.z = t_max.z + t_delta.z;
//         }
//     }

//     return dO;
// }

// // ... (Rest of the code remains the same)

// @compute @workgroup_size(8, 8, 1)
// fn init(@builtin(global_invocation_id) invocation_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
//     let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
//     let color = vec4(0.2);

//     // Initialize grid with large values
//     for (var x = 0; x < GRID_SIZE; x = x + 1) {
//         for (var y = 0; y < GRID_SIZE; y = y + 1) {
//             for (var z = 0; z < GRID_SIZE; z = z + 1) {
//                 grid[x][y][z] = 1000.0;
//             }
//         }
//     }

//     // Add sphere to the grid
//     update_grid(vec3<f32>(0.0, 1.0, 6.0), 1.0);

//     textureStore(texture, location, color);
// }

// @compute @workgroup_size(8, 8, 1)
// fn update(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
//     let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));
//     let res = vec2<f32>(1280., 720.);

//     var uv = (vec2<f32>(invocation_id.xy) - .5 * res.xy) / res.y;
//     uv.y = -uv.y;

//     let ray_origin = vec3(0., 1., 0.);
//     let ray_direction = normalize(vec3<f32>(uv.x, uv.y, 1.));

//     let ray_dist = dda_ray_march(ray_origin, ray_direction);

//     let p = ray_origin + ray_direction * ray_dist;
//     let diffuse = ray_dist / 1000.0; //calclight(p);

//     let color = vec3<f32>(diffuse);

//     storageBarrier();

//     textureStore(texture, location, vec4<f32>(color, 1.0));
// } */