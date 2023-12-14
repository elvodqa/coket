package gfx

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"
import "core:strings"

Vertex :: struct {
    position: glm.vec3,
    normal: glm.vec3,
    tex_coord: glm.vec2,
    color: glm.vec4,    
}

Texture :: struct {
    id: u32,
    path: cstring,
    width: i32,
    height: i32,
    channels: i32,
}

Shader :: struct {
    id: u32,
    vertexPath: string,
    fragmentPath: string,
    uniforms: gl.Uniforms
}

load_shader :: proc(vertPath, fragPath: string) -> (shader: Shader) {
    ok: bool
    shader.id, ok = gl.load_shaders_file(vertPath, fragPath)
    if !ok {
        fmt.printf("Failed to load shader: %s\n", vertPath)
        return shader
    }
   
    shader.vertexPath = vertPath
    shader.fragmentPath = fragPath

    shader.uniforms = gl.get_uniforms_from_program(shader.id)

    return shader
}

load_shader_source :: proc(vert, frag: string) -> (shader: Shader) {
    ok: bool
    shader.id, ok = gl.load_shaders_source(vert, frag)
    if !ok {
        fmt.printf("Failed to load compile shader")
        return shader
    }
   
    shader.uniforms = gl.get_uniforms_from_program(shader.id)

    return shader
}

Mesh :: struct {
    vertices: [dynamic]Vertex,
    indices: [dynamic]u32,
    textures: [dynamic]Texture,
}

load_texture :: proc(texturePath: string) -> (texture: Texture) {
    texture.path = strings.clone_to_cstring(texturePath)
    
    data := stb.load(texture.path, &texture.width, &texture.height, &texture.channels, 0)
    if data == nil {
        fmt.printf("Failed to load texture: %s\n", texturePath)
        return texture
    }
    fmt.println("Loaded texture: ", texturePath)
    fmt.printf("x: %d, y: %d, channels: %d\n", texture.width, texture.height, texture.channels)
    
    gl.GenTextures(1, &texture.id)
    gl.BindTexture(gl.TEXTURE_2D, texture.id)
    
    if texture.channels == 4 {
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture.width, texture.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, &data[0])
    }
    else if texture.channels == 3 {
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, texture.width, texture.height, 0, gl.RGB, gl.UNSIGNED_BYTE, &data[0])
    }
    else {
        fmt.printf("Unsupported number of channels: %d\n", texture.channels)
        return texture
    }
    
    gl.GenerateMipmap(gl.TEXTURE_2D)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.BindTexture(gl.TEXTURE_2D, 0)

    return texture
}

SpriteBatch :: struct {
    shader: Shader,
    meshes: [dynamic]Mesh,
    textures: [dynamic]Texture,
    vao: u32,
    vbo: u32,
    ebo: u32,
    vertexCount: i32,
    indexCount: i32,
}

init :: proc() -> (batch: SpriteBatch) {
    gl.GenVertexArrays(1, &batch.vao)
    gl.GenBuffers(1, &batch.vbo)
    gl.GenBuffers(1, &batch.ebo)
    ok : b32
    batch.shader = load_shader_source(DEFAULT_VERTEX_SHADER, DEFAULT_FRAGMENT_SHADER)

    return batch
}



batch_begin :: proc(batch: ^SpriteBatch) {
    gl.UseProgram(batch.shader.id)
    default_translation := glm.identity(glm.mat4x4) * glm.mat4Translate(glm.vec3{0.0, 0.0, 0.0}) * glm.mat4Scale(glm.vec3{1.0, 1.0, 1.0}) * glm.mat4Rotate(glm.vec3{0.0, 0.0, 1.0}, 0.0) * glm.mat4Rotate(glm.vec3{0.0, 1.0, 0.0}, 0.0) * glm.mat4Rotate(glm.vec3{1.0, 0.0, 0.0}, 0.0) * glm.mat4Translate(glm.vec3{0.0, 0.0, 0.0})
    gl.UniformMatrix4fv(batch.shader.uniforms["translation"].location, 1, false, &default_translation[0, 0])

    gl.BindVertexArray(batch.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, batch.vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, batch.ebo)
}

batch_end :: proc(batch: ^SpriteBatch) {
    gl.BindVertexArray(0)
    gl.UseProgram(0)

    batch.vertexCount = 0
    batch.indexCount = 0
}

batch_draw_texture :: proc(batch: ^SpriteBatch, texture: Texture, position: glm.vec2, size: glm.vec2, color: glm.vec4) {
    vertices: [dynamic]Vertex

    append(&vertices, Vertex{position= glm.vec3{position.x, position.y, 0.0}, tex_coord= glm.vec2{0.0, 0.0}, color= color})
    append(&vertices, Vertex{position= glm.vec3{position.x + size.x, position.y, 0.0}, tex_coord= glm.vec2{1.0, 0.0}, color= color})
    append(&vertices, Vertex{position= glm.vec3{position.x + size.x, position.y + size.y, 0.0}, tex_coord= glm.vec2{1.0, 1.0}, color= color})
    append(&vertices, Vertex{position= glm.vec3{position.x, position.y + size.y, 0.0}, tex_coord= glm.vec2{0.0, 1.0}, color= color})
   

    indices: [dynamic]u32

    append(&indices, 0)
    append(&indices, 1)
    append(&indices, 2)
    append(&indices, 2)
    append(&indices, 3)
    append(&indices, 0)

    

    gl.BindTexture(gl.TEXTURE_2D, texture.id)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(Vertex), &vertices[0], gl.STATIC_DRAW)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), &indices[0], gl.STATIC_DRAW)
    gl.DrawElements(gl.TRIANGLES, cast(i32)len(indices), gl.UNSIGNED_INT, nil)

    gl.BindTexture(gl.TEXTURE_2D, 0)

    batch.vertexCount += cast(i32)len(vertices)
    batch.indexCount += cast(i32)len(indices)
    
    append(&batch.textures, texture)

    append(&batch.meshes, Mesh{vertices= vertices, indices= indices, textures= {texture}})

    //fmt.printf("Batched texture: %s\n", texture.path)
}

clear_screen :: proc(color: glm.vec4 = {0.0, 0.0, 0.0, 1.0}) {
    gl.ClearColor(color.r, color.g, color.b, color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}

color_from_rgba :: proc(r, g, b, a: f32) -> (color: glm.vec4) {
    color.r = r / 255.0
    color.g = g / 255.0
    color.b = b / 255.0
    color.a = a / 255.0
    return color
}

DEFAULT_VERTEX_SHADER :: `
#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 tex_coord;
layout (location = 3) in vec4 color;

out vec3 FragPos;
out vec3 Normal;
out vec2 TexCoord;
out vec4 Color;

//uniform mat4 model;
//uniform mat4 view;
//uniform mat4 projection;
uniform mat4 translation;

void main() {
    FragPos = vec3(translation * vec4(position, 1.0));
    Normal = mat3(transpose(inverse(translation))) * normal;
    TexCoord = tex_coord;
    Color = color;
    gl_Position = translation * vec4(position, 1.0);
}
`

DEFAULT_FRAGMENT_SHADER :: `
#version 330 core

in vec3 FragPos;
in vec3 Normal;
in vec2 TexCoord;
in vec4 Color;

out vec4 FragColor;

uniform sampler2D texture_diffuse1;

void main() {
    FragColor = texture(texture_diffuse1, TexCoord) * Color;
}
`

