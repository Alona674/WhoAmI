shader_type canvas_item;
uniform bool blood = false;
float streak(vec2 uv, float x, float y, float length) {
	return (1.0 - smoothstep(0.004, 0.009, abs(uv.x-x))) * step(y, uv.y) * (1.0-smoothstep(y+length-0.015,y+length,uv.y));
}
void fragment() {
	vec4 original = COLOR;
	if (blood) {
		float mask = max(streak(UV,0.46,0.13,0.07),streak(UV,0.54,0.14,0.06));
		mask = max(mask, 1.0-smoothstep(0.8,1.0,length((UV-vec2(0.48,0.12))/vec2(0.035,0.018))));
		COLOR = vec4(mix(original.rgb,vec3(0.36,0.018,0.012),mask*0.9),original.a);
	}
}
