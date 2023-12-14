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
    ref_count: i32,
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


VERTEX_SHADER :: 
`
#version 400 core

// Vertex attributes for position and color
layout(location = 0) in vec2 in_position;
layout(location = 1) in vec2 in_uv;
layout(location = 2) in vec4 in_color;

// uniform will contain the world matrix.
uniform mat3 screenTransform;

// output variables
out vec2 uv;
out vec4 color;

void main(void)
{
	//transform the vector
	vec3 transformed = screenTransform * vec3(in_position, 1);
	gl_Position = vec4(transformed, 1);
	
	// pass through uv and color
	uv = in_uv;
	color = in_color;
}
`

FRAGMENT_SHADER :: 
`
#version 400 core

in vec2 uv;
in vec4 color;

uniform sampler2D tex;

out vec4 fragColor;

void main(void)
{
	// texelFetch gets a pixel by its index in the texture instead of 0-1 spacing
	fragColor = texelFetch(tex, ivec2(uv), 0) * color;
}
`

Vertex2dUVColor :: struct {
    position: glm.vec2,
    tex_coord: glm.vec2,
    color: glm.vec4,
}

SpriteBatch :: struct {
    vertexBuffer: [dynamic]Vertex2dUVColor,
    vbo: u32,
    shader: Shader,
    texture: ^Texture,
    screenTransform: glm.mat3,
}


new_spritebatch :: proc(screenSize: glm.vec2) -> (batcher: SpriteBatch) {
    batcher.shader = load_shader_source(VERTEX_SHADER, FRAGMENT_SHADER)

    gl.GenBuffers(1, &batcher.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, batcher.vbo)
   
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, size_of(Vertex2dUVColor), 0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, size_of(Vertex2dUVColor), size_of(glm.vec2))
    gl.VertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, size_of(Vertex2dUVColor), size_of(glm.vec4))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    batch_set_size(&batcher, screenSize)

    return batcher
}

batch_draw :: proc(batch: ^SpriteBatch, texture: ^Texture, destRec: glm.vec4, srcRec: glm.vec4, color:glm.vec4) {
    if batch.texture != texture {
        batch_flush(batch)

        texture.ref_count += 1
        if batch.texture != nil {
            batch.texture.ref_count -= 1
            if batch.texture.ref_count == 0 {
                gl.DeleteTextures(1, &batch.texture.id)
                //fmt.printf("Deleted texture: %s\n", batch.texture.path)
            }
        }

        batch.texture = texture
    }

    append(&batch.vertexBuffer, Vertex2dUVColor{glm.vec2{destRec.x, destRec.y}, glm.vec2{srcRec.x, srcRec.y}, color})
    append(&batch.vertexBuffer, Vertex2dUVColor{glm.vec2{destRec.x + destRec.z, destRec.y}, glm.vec2{srcRec.z, srcRec.y}, color})
    append(&batch.vertexBuffer, Vertex2dUVColor{glm.vec2{destRec.x, destRec.y + destRec.w}, glm.vec2{srcRec.x, srcRec.w}, color})
    append(&batch.vertexBuffer, Vertex2dUVColor{glm.vec2{destRec.x + destRec.z, destRec.y}, glm.vec2{srcRec.z, srcRec.y}, color})
    append(&batch.vertexBuffer, Vertex2dUVColor{glm.vec2{destRec.x, destRec.y + destRec.w}, glm.vec2{srcRec.x, srcRec.w}, color})
    append(&batch.vertexBuffer, Vertex2dUVColor{glm.vec2{destRec.x + destRec.z, destRec.y + destRec.w}, glm.vec2{srcRec.z, srcRec.w}, color})

}

batch_flush :: proc(batcher: ^SpriteBatch) {
    if len(batcher.vertexBuffer) == 0 || batcher.texture == nil {
        return
    }

    gl.UseProgram(batcher.shader.id)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, batcher.texture.id)
    gl.Uniform1i(batcher.shader.uniforms["tex"].location, 0)

    gl.BindBuffer(gl.ARRAY_BUFFER, batcher.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex2dUVColor) * len(batcher.vertexBuffer), &batcher.vertexBuffer[0], gl.STATIC_DRAW)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.UniformMatrix3fv(batcher.shader.uniforms["screenTransform"].location, 1, gl.FALSE, &batcher.screenTransform[0, 0])

    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)

    gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)len(batcher.vertexBuffer))

    gl.DisableVertexAttribArray(0)
    gl.DisableVertexAttribArray(1)
    gl.DisableVertexAttribArray(2)

    batcher.vertexBuffer = {}
}

// set screen size for batcher
batch_set_size :: proc(batcher: ^SpriteBatch, screenSize: glm.vec2) {
    batcher.screenTransform[0][0] = 2.0 / screenSize.x
    batcher.screenTransform[1][1] = 2.0 / screenSize.y
    batcher.screenTransform[2][0] = -1.0
    batcher.screenTransform[2][1] = -1.0
}
