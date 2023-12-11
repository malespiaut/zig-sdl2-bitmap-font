const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
});
var prng = std.rand.DefaultPrng.init(0);
var xoshiro = prng.random();

const k_screen_width: i32 = 320;
const k_screen_height: i32 = 240;

var g_window: *c.SDL_Window = undefined;
var g_renderer: *c.SDL_Renderer = undefined;
var g_texture: *c.SDL_Texture = undefined;

var g_quit: bool = false;

// Font
//const FontName = enum { gob33, plettre };
//var g_font: [2]Font = undefined;

var g_font_gob33: Font = undefined;
var g_font_plettre: Font = undefined;
var g_font_lettre: Font = undefined;

const FontRW = struct {
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    char_width: u8,
    char_height: u8,
    char_rects: [256]c.SDL_Rect,

    pub fn init(renderer: *c.SDL_Renderer, file: []const u8, char_width: u8, char_height: u8) Font {
        var result: Font = Font{
            .renderer = undefined,
            .texture = undefined,
            .char_width = 0,
            .char_height = 0,
            .char_rects = undefined,
        };

        const rw: *c.SDL_RWops = c.SDL_RWFromConstMem(file.ptr, @as(c_int, @intCast(file.len))) orelse {
            c.SDL_Log("Unable to get RWFromConstMem: %s", c.SDL_GetError());
            //return error.SDLRWFromConstMemFailed;
            return result;
        };
        defer std.debug.assert(c.SDL_RWclose(rw) == 0);

        const texture: *c.SDL_Texture = c.IMG_LoadTexture_RW(renderer, rw, 0) orelse {
            c.SDL_Log("Unable to load image as texture: %s", c.SDL_GetError());
            //return error.SDLIMGLoadTextureFailed;
            return result;
        };

        var char_rects: [256]c.SDL_Rect = undefined;
        var char_code: usize = 0;
        for (0..16) |row| {
            for (0..16) |column| {
                char_rects[char_code].x = char_width * @as(i32, @intCast(column));
                char_rects[char_code].y = char_height * @as(i32, @intCast(row));
                char_rects[char_code].w = char_width;
                char_rects[char_code].h = char_height;
                char_code += 1;
            }
        }

        result.renderer = renderer;
        result.texture = texture;
        result.char_width = char_width;
        result.char_height = char_height;
        result.char_rects = char_rects;
        return result;
    }
};

//XXX: Older implementation that don't embed the file.
const Font = struct {
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    char_width: u8,
    char_height: u8,
    char_rects: [256]c.SDL_Rect,

    pub fn init(renderer: *c.SDL_Renderer, char_sheet_path: [*c]const u8, char_width: u8, char_height: u8) Font {
        const texture: *c.SDL_Texture = c.IMG_LoadTexture(renderer, char_sheet_path) orelse {
            c.SDL_Log("Unable to load image as texture: %s", c.SDL_GetError());
            //return error.SDLIMGLoadTextureFailed;
            return Font{
                .renderer = null,
                .texture = null,
                .char_width = 0,
                .char_height = 0,
                .char_rects = undefined,
            };
        };

        var char_rects: [256]c.SDL_Rect = undefined;
        var char_code: usize = 0;
        for (0..16) |row| {
            for (0..16) |column| {
                char_rects[char_code].x = char_width * @as(i32, @intCast(column));
                char_rects[char_code].y = char_height * @as(i32, @intCast(row));
                char_rects[char_code].w = char_width;
                char_rects[char_code].h = char_height;
                char_code += 1;
            }
        }

        return Font{
            .renderer = renderer,
            .texture = texture,
            .char_width = char_width,
            .char_height = char_height,
            .char_rects = char_rects,
        };
    }
};

pub fn text_print(string: []const u8, position: c.SDL_Point, font: Font) void {
    var current: c.SDL_Point = c.SDL_Point{ .x = position.x, .y = position.y };

    for (string) |char| {
        // Handle new line '\n'
        if (char == '\n') {
            current.x = position.x;
            current.y += font.char_height;
        } else {
            // Wrap long lines
            if (current.x + font.char_width > k_screen_width) {
                current.x = position.x;
                current.y += font.char_height;
            }

            // Normal printing operation
            var r: c.SDL_Rect = c.SDL_Rect{
                .x = current.x,
                .y = current.y,
                .w = font.char_width,
                .h = font.char_height,
            };

            if (c.SDL_RenderCopy(font.renderer, font.texture, &font.char_rects[char], &r) != 0) {
                c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                //XXX: I don't yet understand how to handle return errors that aren't in main().
                //return error.SDLRenderCopyFailed;
            }
            current.x += font.char_width;
        }
    }
}

pub fn text_print_sine(string: []const u8, position: c.SDL_Point, font: Font) void {
    const StaticCounter = struct {
        var i: f32 = 0.0;
    };

    var current: c.SDL_Point = c.SDL_Point{ .x = position.x, .y = position.y };

    for (string) |char| {
        // Handle new line '\n'
        if (char != '\n') {
            // Normal printing operation
            var r: c.SDL_Rect = c.SDL_Rect{
                .x = current.x,
                .y = current.y + @as(i32, @intFromFloat(@sin(StaticCounter.i) * 10.0)),
                .w = font.char_width,
                .h = font.char_height,
            };

            if (c.SDL_RenderCopy(font.renderer, font.texture, &font.char_rects[char], &r) != 0) {
                c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                //XXX: I don't yet understand how to handle return errors that aren't in main().
                //return error.SDLRenderCopyFailed;
            }
            current.x += font.char_width;
            StaticCounter.i += 0.01;
        }
    }
}

// Engine
fn events_process() void {
    c.SDL_PumpEvents();
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_QUIT => {
                g_quit = true;
                break;
            },
            c.SDL_WINDOWEVENT => {
                if (event.window.event == c.SDL_WINDOWEVENT_CLOSE) {
                    g_quit = true;
                }
                break;
            },
            else => {
                break;
            },
        }
    }
}

fn game_init() !void {
    g_font_gob33 = FontRW.init(g_renderer, @embedFile("gob33.png"), 8, 10);
    g_font_plettre = FontRW.init(g_renderer, @embedFile("plettre.png"), 6, 12);
    g_font_lettre = FontRW.init(g_renderer, @embedFile("lettre.png"), 8, 8);
}

fn game_update() void {
    text_print("Bonjour \x85 tous ! Appr\x82ciez-vous cette \x82criture cursive ? N'oubilez pas d'envoyer un courriel \x85 logicoq@free.fr\nLogicoq, les cocoricogiciels ! ;)", c.SDL_Point{ .x = 0, .y = 0 }, g_font_gob33);
    text_print("Bonjour \x85 tous ! Appr\x82ciez-vous cette \x82criture cursive ? N'oubilez pas d'envoyer un courriel \x85 logicoq@free.fr\nLogicoq, les cocoricogiciels ! ;)", c.SDL_Point{ .x = 0, .y = 40 }, g_font_plettre);
    text_print_sine("PLEASE REVIEW MY CODE!!!", c.SDL_Point{ .x = 100, .y = 100 }, g_font_lettre);
}

fn game_draw() void {}

fn frame_present() void {
    c.SDL_RenderPresent(g_renderer);
    if (c.SDL_SetRenderDrawColor(g_renderer, 0, 0, 0, 255) != 0) {
        c.SDL_Log("Unable to set color for the rendering target: %s", c.SDL_GetError());
        //XXX: I don't yet understand how to handle return errors that aren't in main().
        //return error.SDLSetRenderDrawColorFailed;
    }
    if (c.SDL_RenderClear(g_renderer) != 0) {
        c.SDL_Log("Unable to clear the rendering target: %s", c.SDL_GetError());
        g_quit = true;
        //XXX: I don't yet understand how to handle return errors that aren't in main().
        //return error.SDLRenderClearFailed;
    }
}

pub fn main() !void {
    // The whole SDL init
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    g_window = c.SDL_CreateWindow("Bitmap font test", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, k_screen_width, k_screen_height, c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI) orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLCreateWindowFailed;
    };
    defer c.SDL_DestroyWindow(g_window);

    g_renderer = c.SDL_CreateRenderer(g_window, -1, c.SDL_RENDERER_PRESENTVSYNC) orelse
        {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLCreateRendererFailed;
    };
    defer c.SDL_DestroyRenderer(g_renderer);

    if (c.SDL_RenderSetLogicalSize(g_renderer, k_screen_width, k_screen_height) != 0) {
        c.SDL_Log("Unable to set independent resolution for rendering: %s", c.SDL_GetError());
        //XXX: Not sure if execution should stop because of that.
        //return error.SDLRenderSetLogicalSizeFailed;
    }

    try game_init();

    // Game loop
    while (!g_quit) {
        events_process();
        game_update();
        game_draw();
        frame_present();
    }
}
