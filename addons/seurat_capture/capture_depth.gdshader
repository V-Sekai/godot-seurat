shader_type spatial;
render_mode cull_disabled,  unshaded, depth_draw_always; // unshaded to get the unmodified color out into the texture

varying mat4 CAMERA;
uniform float camera_near = 0.005;
uniform float camera_far = 4000.0;

void vertex() {
  POSITION = vec4(VERTEX, 1.0);
  CAMERA = INV_VIEW_MATRIX;
}

void fragment() {
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_z = -view.z;
	//	ALPHA = (depth < 1.0) ? 1.0 : 0.0; 
	if (depth == 1.0) {
		linear_z = 0.0; 
	}
	float z = linear_z * (camera_far - camera_near) - camera_near;
	ALBEDO.xyz = vec3(1.0 - z); // This will get clamped to 0-1 in Godot 4.0 if you are reading this later from a Viewport
}