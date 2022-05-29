shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_always; // unshaded to get the unmodified color out into the texture

varying mat4 CAMERA;

void vertex() {
  POSITION = vec4(VERTEX, 1.0); // we render a screen space quad with this shader; so no transform
  CAMERA = INV_VIEW_MATRIX;
}


void fragment() {
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 world = CAMERA * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_position = world.xyz / world.w;
    ALBEDO = vec3(world_position.z);
}