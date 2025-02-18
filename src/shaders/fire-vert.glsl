#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform float u_Time;
uniform float u_Speed;
uniform float u_Height;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;
out vec2 fs_UV;
out float fs_BlendNoise;

const vec4 lightPos = vec4(5, 5, 20, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.


//=----------Fire Shader
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float hermite(float t)
{
  return t * t * (3.0 - 2.0 * t);
}

float noise(vec2 co, float frequency)
{
  vec2 v = vec2(co.x * frequency, co.y * frequency);

  float ix1 = floor(v.x);
  float iy1 = floor(v.y);
  float ix2 = floor(v.x + 1.0);
  float iy2 = floor(v.y + 1.0);

  float fx = hermite(fract(v.x));
  float fy = hermite(fract(v.y));

  float fade1 = mix(rand(vec2(ix1, iy1)), rand(vec2(ix2, iy1)), fx);
  float fade2 = mix(rand(vec2(ix1, iy2)), rand(vec2(ix2, iy2)), fx);

  return mix(fade1, fade2, fy);
}

float pnoise(vec2 co, float freq, int steps, float persistence)
{
  float value = 0.0;
  float ampl = 1.0;
  float sum = 0.0;
  for(int i=0 ; i<steps ; i++)
  {
    sum += ampl;
    value += noise(co, freq) * ampl;
    freq *= 2.0;
    ampl *= persistence;
  }
  return value / sum;
}



// ------------------- Base Noise --------------------------

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

float rand1(float value){
	float random = u_Height * fract(sin(value + 0.943) * 1423558.53253);
	return random;
}

//--------------------Lerp --------------------------
float smoothMax(float a, float b, float k) {
       k = min(0.0, -k);
       float h = max(0.0, min(1.0, (b - a + k) / (2.0 * k)));
       return a * h + b * (1.0 - h) - k * h * (1.0 - h);
}

float blend(float startHeight, float blendDst, float height) {
        return smoothstep(startHeight - blendDst / 2.0, startHeight + blendDst / 2.0, height);
}

// ------------------- FBM --------------------------
float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

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

float fbm (vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}

float fbm3d (vec3 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise3d(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}

// ------------------- CALCULATE UV --------------------------
vec2 uv(vec3 pos){
    pos = normalize(pos);
    float u = 0.5 + atan(pos.x, pos.z)/6.28318;
    float v = 0.5 + asin(pos.y)/3.14159;
    return vec2(u, v);
}

float bias(float b, float t) {
    return (pow(t, log(b)) / log(0.5));
}

//-------------------- RIGID NOISE ---------------------------

float ridgidNoise(vec3 pos) {
    vec3 offset = vec3(cos(u_Time*0.001));
    float lacunarity = 0.5;

      // Sum up noise layers
    float scale = 1.5;
    float noiseSum = 0.0;
    float frequency = scale;
    float ridgeWeight = 1.0;
    float amplitude = 2.0;
    
    for (float i = 0.0; i < 5.0; i ++) {
        float noiseVal = 1.0 - abs(noise3d(pos * frequency + offset));
        noiseVal = pow(abs(noiseVal), 3.0);
        noiseVal *= ridgeWeight;
        ridgeWeight = clamp(noiseVal * 0.8,0.0,1.0);
        noiseSum += noiseVal * 2.0;
        amplitude *= 0.5;
        frequency *= lacunarity;
    }
    return noiseSum * 11.0;
  }

  float smoothedRidgidNoise(vec3 pos) {
      vec3 sphereNormal = normalize(pos);
      vec3 axisA = cross(sphereNormal, vec3(0.0,1.0,0.0));
      vec3 axisB = cross(sphereNormal, axisA);

      float offsetDst = 8.0*0.05;
      float sample0 = ridgidNoise(pos);
      float sample1 = ridgidNoise(pos - axisA * offsetDst);
      float sample2 = ridgidNoise(pos + axisA * offsetDst);
      float sample3 = ridgidNoise(pos - axisB * offsetDst);
      float sample4 = ridgidNoise(pos + axisB * offsetDst);
      return (sample0 + sample1 + sample2 + sample3 + sample4) / 5.0;
  }

//--------------------Pseudo 3d ---------------------
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
    fs_Col = vs_Col;

    
    vec3 pos = (vec3(vs_Pos.x + rand1(u_Time) * 0.001, vs_Pos.y + u_Time * 0.003, vs_Pos.z + u_Time * 0.005 * u_Speed) / vec3(0.3));
    float noise = Pseudo3dNoise(pos) + fbm3d(pos) + pnoise(pos.xy, 2.0, 2, u_Height)+ u_Height;
    
    float base_noise = Pseudo3dNoise(pos);
    base_noise = smoothMax(base_noise,-10.0, 1.0);
    base_noise = abs(base_noise);
    float mask = blend(0.0,0.6,fbm3d(pos));
    float ridgeNoise = smoothedRidgidNoise(pos);
    float fireNoise = base_noise * 0.01 + ridgeNoise * 0.01 * mask;
    fs_BlendNoise = fireNoise;

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.
    float fbmNoise3d = 0.2 * fbm3d(pos * 3.0);
    fs_Col = vec4(fbmNoise3d, fbmNoise3d, fbmNoise3d, 1.0);

    vec4 deformedPos = vs_Pos + vs_Nor  * fbmNoise3d * noise + fireNoise;
    fs_Pos = deformedPos;

    vec4 modelposition = u_Model * deformedPos;   // Temporarily store the transformed vertex positions for use below

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies
    fs_Pos = modelposition;
    

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
