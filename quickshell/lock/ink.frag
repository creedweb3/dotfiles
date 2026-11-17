#version 440
// Manga lock ink: grey the panel, then map black -> shadow and white -> highlight (the demo's SVG
// feColorMatrix + feComponentTransfer table), and cut it to the panel's polygon (mask alpha).
// colour > 0.5 keeps the page's own colours. Compiled at runtime to ~/.cache/rice/ink.frag.qsb
// with qsb (qt6-shadertools); without it the lock falls back to plain grey panels.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 shadow;
    vec4 highlight;
    float colour;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D maskSource;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    float m = texture(maskSource, qt_TexCoord0).a;
    vec3 rgb = c.a > 0.0 ? c.rgb / c.a : c.rgb;
    float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 o = colour > 0.5 ? rgb : mix(shadow.rgb, highlight.rgb, l);
    float a = c.a * m * qt_Opacity;
    fragColor = vec4(o * a, a);
}
