#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform float u_Time;
uniform sampler2D u_Texture;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;
in vec2 fs_UV;
in float fs_BlendNoise;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

float bias(float b, float t) {
    return (pow(t, log(b)) / log(0.5));
}

float gain(float g, float t) {
    if (t < 0.5f) {
        return (bias(1.0 - g, 2.0 * t) / 2.0);
    }
    else {
        return (1.0 - bias(1.0 - g, 2.0 - 2.0 * t) / 2.0);
    }
}

// ------------------- Base Noise --------------------------

float rand3to1(vec3 value, vec3 dotDir){
    //make value smaller to avoid artefacts
    vec3 smallValue = sin(value);
    //get scalar value from 3d vector
    float random = dot(smallValue, dotDir);
    //make value more random by making it bigger and then taking the factional part
    random = fract(sin(random) * 234234.2394234);
    return random;
}

vec3 rand3d(vec3 value){
    return vec3(
        rand3to1(value, vec3(452.929, 78.233, 35.1234)),
        rand3to1(value, vec3(235.126, 23.3441, 30.5434)),
        rand3to1(value, vec3(34.3456, 52.23754, 39.221))
    );
}

float easeIn(float interpolator){
	return interpolator * interpolator * interpolator * interpolator * interpolator;
}

float easeOut(float interpolator){
	return 1.0 - easeIn(1.0 - interpolator);
}

float easeInOut(float interpolator){
    float easeInValue = easeIn(interpolator);
    float easeOutValue = easeOut(interpolator);
    return mix(easeInValue, easeOutValue, interpolator);
}

float rand1dTo1d(float value){
	float random = fract(sin(value + 0.546) * 143758.5453);
	return random;
}

// ------------------- FBM2D --------------------------
float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(223.98,7233.213)))*
        324908.0092123);
}

float hashnew (vec2 n)
{
    return fract(sin(dot(n, vec2(123.456789, 987.654321))) * 54321.9876 );
}

// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = hashnew(i);
    float b = hashnew(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm (vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}

// ------------------- FBM3D --------------------------
float hash(float h) {
	return fract(sin(h) * 43758.5453123);
}

float noise3d (vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);

	float n = p.x + p.y * 157.0 + 113.0 * p.z;
	return mix(
			mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
					mix(hash(n + 205.0), hash(n + 328.0), f.x), f.y),
			mix(mix(hash(n + 133.0), hash(n + 114.0), f.x),
					mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

// ------------------- FBM3D --------------------------
// fbm noise for 2-4 octaves including rotation per octave

float fbm3d (vec3 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise3d(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}

//-------------------3D SIMPLEX -----------------------
vec3 random3(vec3 c) {
    float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
    vec3 r;
    r.z = fract(512.0*j);
    j *= .125;
    r.x = fract(512.0*j);
    j *= .125;
    r.y = fract(512.0*j);
    return r-0.5;
}

const float F3 =  0.3333333;
const float G3 =  0.1666667;
float snoise(vec3 p) {

    vec3 s = floor(p + dot(p, vec3(F3)));
    vec3 x = p - s + dot(s, vec3(G3));
     
    vec3 e = step(vec3(0.0), x - x.yzx);
    vec3 i1 = e*(1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy*(1.0 - e);
         
    vec3 x1 = x - i1 + G3;
    vec3 x2 = x - i2 + 2.0*G3;
    vec3 x3 = x - 1.0 + 3.0*G3;
     
    vec4 w, d;
     
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);
     
    w = max(0.6 - w, 0.0);
     
    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);
     
    w *= w;
    w *= w;
    d *= w;
     
    return dot(d, vec4(52.0));
}

float snoiseFractal(vec3 m) {
    return   0.5333333* snoise(m)
                +0.2666667* snoise(2.0*m)
                +0.1333333* snoise(4.0*m)
                +0.0666667* snoise(8.0*m);
}

// ------------------ REMAP RELATED FUNCTION---------

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}
float remap01(float v, float minOld, float maxOld) {
    return clamp((v-minOld) / (maxOld-minOld),0.0,1.0);
}

//--------------------Pseudo 3d ---------------------
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
vec2 GetGradient(vec2 intPos, float t) {
    
    // Uncomment for calculated rand
    //float rand = fract(sin(dot(intPos, vec2(12.9898, 78.233))) * 43758.5453);;
    
    // Texture-based rand (a bit faster on my GPU)
    float rand = rand(intPos);
    
    // Rotate gradient: random starting rotation, random rotation rate
    float angle = 6.283185 * rand + 4.0 * t * rand;
    return vec2(cos(angle), sin(angle));
}


float Pseudo3dNoise(vec3 pos) {
    vec2 i = floor(pos.xy);
    vec2 f = pos.xy - i;
    vec2 blend = f * f * (3.0 - 2.0 * f);
    float noiseVal =
        mix(
            mix(
                dot(GetGradient(i + vec2(0, 0), pos.z), f - vec2(0, 0)),
                dot(GetGradient(i + vec2(1, 0), pos.z), f - vec2(1, 0)),
                blend.x),
            mix(
                dot(GetGradient(i + vec2(0, 1), pos.z), f - vec2(0, 1)),
                dot(GetGradient(i + vec2(1, 1), pos.z), f - vec2(1, 1)),
                blend.x),
        blend.y
    );
    return noiseVal / 0.7; // normalize to about [-1..1]
}

// ------------------- MAIN --------------------------

void main()
{
    // Material base color (before shading)
    vec4 diffuseColor = u_Color;

    float fbmNoise = fbm(fs_UV); 
    float fbmNoise3D = snoiseFractal(fs_Pos.xyz) + 0.1;
    vec4 col = u_Color;

    vec3 pos = vec3(fs_Pos.x + rand1dTo1d(u_Time) * 0.001, fs_Pos.y + u_Time * 0.003, fs_Pos.z + u_Time * 0.005) / vec3(0.3);
    float noise = Pseudo3dNoise(pos) + 0.5;

    float dist = length(fs_Pos) * 0.2;
    
    float brightness = 0.3;
    
    // fire and ball
    vec4 fire_color = vec4(1.0, 1.0, 0.4, 1.0);
    vec4 ball_color = vec4(1.0, 0.0, 0.0, 1.0)+vec4(vec3(sin(u_Time*0.002)*(snoise(fs_Pos.xyz)+1.0))*0.02,1.0);

    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 0.5);
    vec3 d = vec3(0.80, 0.90, 0.30);
    vec4 border_color = vec4(1.0, 0.8, 0.0, 1.0);
    vec3 SpecularColor = palette(sin(u_Time*0.001),a,b,c,d)*0.5;
    diffuseColor = mix(ball_color * 0.5, u_Color, 0.8);
    vec3 specularTerm = vec3(0.0);
    float shininess = 0.2;
    
    
    vec3 localNormal = normalize(fs_Pos.xyz);
    float steepness = 1.0 - dot(localNormal, vec3(fs_Nor));
    steepness = remap01(steepness, 0.0, 0.05);

    float steepThreshold=0.7;
   float elevationThreshold=0.3;
    vec3 steepCol = vec3(fire_color);
    float noiseLerp = snoise(vec3(fs_Pos))*0.05;
    
    vec3 flatCol = vec3(fire_color);
    float flatStrength = 1.0 - bias(steepness,0.8)*0.5;

    vec3 redFireCol = mix(steepCol, flatCol, flatStrength);
    if(fs_BlendNoise <= (0.1 + noiseLerp + sin(u_Time*0.01)*0.01)){
        float shoreStrength = 1.0 - bias(fs_BlendNoise *10.0,0.3);
        redFireCol = mix(redFireCol, vec3(border_color), shoreStrength);
    }
    
    diffuseColor += vec4(redFireCol,1.0);

    
    vec3 n = normalize(fs_Pos.xyz - vec3(0.0));
    float u = atan(n.x, n.z) / (2.0 * 3.14159) + 0.5;
    float v = n.y*0.5+0.5;
    vec4 text = texture(u_Texture,vec2(u,v));
    diffuseColor = mix(diffuseColor, text, 0.8);

    vec4 texture = texture(u_Texture, vec2(fbmNoise3D + 0.02, fbmNoise3D));

    vec3 red = vec3(0.7, 0.2, 0.0);
    vec3 orangered = vec3(1.0, 0.87, 0.242);

    col = vec4(dist, dist, dist, 1.0);
    vec3 mixCol = mix(red, orangered, dist);
    col.xyz = mixCol;
    out_Col = vec4((diffuseColor.rgb), diffuseColor.a);
}
