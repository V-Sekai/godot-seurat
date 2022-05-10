shader_type spatial;
render_mode cull_disabled, unshaded; // unshaded to get the unmodified color out into the texture

varying mat4 CAMERA;

void vertex() {
  CAMERA = INV_VIEW_MATRIX;
}


void fragment() {
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	// ALPHA = (frag_z<1.0)?1.0:0.0; // this currently does not work to export via exr; would be usefull as depth mask
	
	if (linear_depth == 1.0) linear_depth = 0.0; // set to 0.0 when we are at or behind the far plane (seurat will detect this)
	
	ALBEDO.rgb = vec3(linear_depth);
}
