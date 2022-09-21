import {vec3} from 'gl-matrix';
import {vec4} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';
import {gl} from './globals';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Load Scene': loadScene, // A function pointer, essentially
  speed: 1,
  fireHeight: 1,
};

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let prevTesselations: number = 5;
let time: number = 0;
let prevSpeed : number = 1;
let prevHeight: number = 1;


function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();
}


function loadTexture(url: string) {
  const texture = gl.createTexture();
  const image = new Image();

  image.onload = e => {
      gl.bindTexture(gl.TEXTURE_2D, texture);
      
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);

      gl.generateMipmap(gl.TEXTURE_2D);
  };

  image.src = url;
  return texture;
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'Load Scene');
  var palette = {
    color: [ 255, 195, 75, 255 ], // RGB with alpha
  };
  gui.addColor(palette, 'color');
  gui.add(controls, 'speed', 0, 10).step(1);
  gui.add(controls, 'fireHeight', 0.1, 2).step(0.1);

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  // ---- load texture
  const gradientTexture = loadTexture('../texture/fire.jpeg');
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, gradientTexture);

  const gradientTexture2 = loadTexture('../texture/gradient2.png');
  gl.activeTexture(gl.TEXTURE1);
  gl.bindTexture(gl.TEXTURE_2D, gradientTexture2);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert-frag.glsl')),
  ]);
  lambert.setGeometryColor(vec4.fromValues(palette.color[0]/255.0, palette.color[1]/255.0, 
  palette.color[2]/255.0, palette.color[3]));


  const fireShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/fire-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/fire-frag.glsl')),
  ])


  fireShader.setTexture(0);

  // This function will be called every frame
  function tick() {
    time = time + 1;
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }

    if(prevSpeed !==  controls.speed){
      prevSpeed = controls.speed;
      fireShader.setSpeed(controls.speed);
    }

    if(prevHeight !==  controls.fireHeight){
      prevSpeed = controls.fireHeight;
      fireShader.setHeight(controls.fireHeight);
    }


    lambert.setGeometryColor(vec4.fromValues(palette.color[0]/255.0, palette.color[1]/255.0,
                                             palette.color[2]/255.0, palette.color[3]));
    fireShader.setGeometryColor(vec4.fromValues(palette.color[0]/255.0, palette.color[1]/255.0,
                                             palette.color[2]/255.0, palette.color[3])); 
    fireShader.setTime(time);                                                   
    renderer.render(camera, fireShader, [
      icosphere,
      //square
      //cube
    ]);
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
