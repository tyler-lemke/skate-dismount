shader_type spatial;
render_mode cull_back;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float severity : hint_range(0.0, 100.0) = 0.0;
uniform float roughness_value = 0.65;
void fragment() {
 // Irregular localized abrasion; preserve the original cloth/skin material away from it.
 float grain = sin(UV.x * 73.0 + sin(UV.y * 29.0) * 4.0) * sin(UV.y * 57.0);
 float patch = smoothstep(0.22, 0.76, sin(UV.x * 12.0) * cos(UV.y * 9.0) + grain * 0.18);
 float amount = severity / 100.0;
 vec3 bruise = mix(vec3(0.34, 0.055, 0.09), vec3(0.16, 0.035, 0.12), amount);
 ALBEDO = mix(base_color.rgb, bruise, patch * amount * 0.84);
 ROUGHNESS = min(1.0, roughness_value + amount * patch * 0.2);
}
