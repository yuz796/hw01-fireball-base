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
uniform sampler2D u_Texture2D;
uniform sampler2D u_Textures;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;
in vec2 fs_UV;

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

// ------------------- 3D PERLIN --------------------------

float rand3dTo1d(vec3 value, vec3 dotDir){
    //make value smaller to avoid artefacts
    vec3 smallValue = sin(value);
    //get scalar value from 3d vector
    float random = dot(smallValue, dotDir);
    //make value more random by making it bigger and then taking the factional part
    random = fract(sin(random) * 143758.5453);
    return random;
}

vec3 rand3dTo3d(vec3 value){
    return vec3(
        rand3dTo1d(value, vec3(12.989, 78.233, 37.719)),
        rand3dTo1d(value, vec3(39.346, 11.135, 83.155)),
        rand3dTo1d(value, vec3(73.156, 52.235, 09.151))
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

float perlinNoise(vec3 value){
    vec3 fraction = fract(value);

    float interpolatorX = easeInOut(fraction.x);
    float interpolatorY = easeInOut(fraction.y);
    float interpolatorZ = easeInOut(fraction.z);

    float cellNoiseZ[2];
    for(int z=0;z<=1;z++){
        float cellNoiseY[2];
        for(int y=0;y<=1;y++){
            float cellNoiseX[2];
            for(int x=0;x<=1;x++){
                vec3 cell = floor(value) + vec3(x, y, z);
                vec3 cellDirection = rand3dTo3d(cell) * 2.0 - 1.0;
                vec3 compareVector = fraction - vec3(x, y, z);               
                cellNoiseX[x] = dot(cellDirection, compareVector);
            }
            cellNoiseY[y] = mix(cellNoiseX[0], cellNoiseX[1], interpolatorX);
        }
        cellNoiseZ[z] = mix(cellNoiseY[0], cellNoiseY[1], interpolatorY);
    }
    float noise = mix(cellNoiseZ[0], cellNoiseZ[1], interpolatorZ);
    return noise;
}

float rand1dTo1d(float value){
	float random = fract(sin(value + 0.546) * 143758.5453);
	return random;
}

// ------------------- FBM2D --------------------------
float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
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
					mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
			mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
					mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

// ------------------- FBM3D --------------------------
// fbm noise for 2-4 octaves including rotation per octave

#define OCTAVES 6
float fbm3d (vec3 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
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


// ------------------- MAIN --------------------------

void main()
{
    // Material base color (before shading)
    vec4 diffuseColor = u_Color;

    float fbmNoise = fbm(fs_UV); 
    float fbmNoise3D = snoiseFractal(fs_Pos.xyz) + 0.1;
    vec4 col = u_Color;

    vec3 pos = vec3(fs_Pos.x + rand1dTo1d(u_Time) * 0.001, fs_Pos.y + u_Time * 0.003, fs_Pos.z + u_Time * 0.005) / vec3(0.3);
    float noise = perlinNoise(pos) + 0.5;

    float dist = length(fs_Pos) * 0.2;
    
    float brightness = 0.3;
    vec3 n = normalize(fs_Pos.xyz - vec3(0.0));
    float u = atan(n.x, n.z) / (2.0 * 3.14159) + 0.5;
    float v = n.y*0.5+0.5;
    vec4 text = texture(u_Texture2D,vec2(u,v));
    diffuseColor = mix(diffuseColor, text, 0.8);
    
    
    float starGlow	= min( max( 1.0 - dist * ( 1.0 - brightness), 0.0 ), 1.0 );

    vec4 texture = texture(u_Texture2D, vec2(fbmNoise3D + 0.02, fbmNoise3D));
    
    //vec4 b = texture(u_Textures, vec2(fbmNoise3D, fbmNoise3D));

    vec3 red = vec3(0.7, 0.2, 0.0);
    vec3 orange = vec3(255.0 / 255.0, 190.0 / 255.0, 78.0 / 255.0);

    col = vec4(dist, dist, dist, 1.0);
    vec3 mixCol = mix(red, orange, dist);
    col.xyz = mixCol;

    // Calculate the diffuse term for Lambert shading
    //float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
    // Avoid negative lighting values
    //diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);
    //float ambientTerm = 0.2;
    //float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                        //to simulate ambient lighting. This ensures that faces that are not
                                                        //lit by our point light are not completely black.

    // Compute final shaded color
    //out_Col = vec4(texture.xyz, 1.0);
    out_Col = vec4((diffuseColor.rgb), diffuseColor.a);
    //out_Col = vec4(brightness, brightness, brightness, 1.0);
    //out_Col = fs_Col;
}
