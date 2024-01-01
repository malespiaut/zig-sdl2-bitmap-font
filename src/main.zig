const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
    @cInclude("SDL2/SDL_mixer.h");
});
var prng = std.rand.DefaultPrng.init(0);
var xoshiro = prng.random();

const k_screen_width: i32 = 320;
const k_screen_height: i32 = 240;

var g_window: *c.SDL_Window = undefined;
var g_renderer: *c.SDL_Renderer = undefined;
var g_texture: *c.SDL_Texture = undefined;

var g_quit: bool = false;

var g_font: Font = undefined;

const Font = struct {
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    char_width: u8,
    char_height: u8,
    char_rects: [256]c.SDL_Rect,

    pub fn init(renderer: *c.SDL_Renderer, file: []const u8, char_width: u8, char_height: u8) Font {
        const result: Font = Font{
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

        return Font{
            .renderer = renderer,
            .texture = texture,
            .char_width = char_width,
            .char_height = char_height,
            .char_rects = char_rects,
        };
    }

    pub fn static(self: Font, string: []const u8, position: c.SDL_Point) void {
        var current: c.SDL_Point = c.SDL_Point{ .x = position.x, .y = position.y };

        for (string) |char| {
            // Handle new line '\n'
            if (char == '\n') {
                current.x = position.x;
                current.y += self.char_height;
            } else {
                // Wrap long lines
                if (current.x + self.char_width > k_screen_width) {
                    current.x = position.x;
                    current.y += self.char_height;
                }

                // Normal printing operation
                var r: c.SDL_Rect = c.SDL_Rect{
                    .x = current.x,
                    .y = current.y,
                    .w = self.char_width,
                    .h = self.char_height,
                };

                if (c.SDL_RenderCopy(self.renderer, self.texture, &self.char_rects[char], &r) != 0) {
                    c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                    //XXX: I don't yet understand how to handle return errors that aren't in main().
                    //return error.SDLRenderCopyFailed;
                }
                current.x += self.char_width;
            }
        }
    }

    pub fn shake(self: Font, string: []const u8, position: c.SDL_Point) void {
        var current: c.SDL_Point = c.SDL_Point{ .x = position.x, .y = position.y };

        for (string) |char| {
            var r: c.SDL_Rect = c.SDL_Rect{
                .x = current.x + @mod(xoshiro.int(i32), 4),
                .y = current.y + @mod(xoshiro.int(i32), 4),
                .w = self.char_width,
                .h = self.char_height,
            };

            if (c.SDL_RenderCopy(self.renderer, self.texture, &self.char_rects[char], &r) != 0) {
                c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                //XXX: I don't yet understand how to handle return errors that aren't in main().
                //return error.SDLRenderCopyFailed;
            }
            current.x += self.char_width;
        }
    }

    pub fn static_sine(self: Font, string: []const u8, position: c.SDL_Point) void {
        const StaticCounter = struct {
            var i: f32 = 0.0;
        };

        var current: c.SDL_FPoint = c.SDL_FPoint{ .x = @as(f32, @floatFromInt(position.x)), .y = @as(f32, @floatFromInt(position.y)) };

        for (string) |char| {
            var r: c.SDL_FRect = c.SDL_FRect{
                .x = current.x,
                .y = current.y + @sin(current.x * 0.05 + StaticCounter.i) * 20, //@sin(current.x + StaticCounter.i + 10) * 1.0,
                .w = @as(f32, @floatFromInt(self.char_width)),
                .h = @as(f32, @floatFromInt(self.char_height)),
            };

            if (c.SDL_RenderCopyF(self.renderer, self.texture, &self.char_rects[char], &r) != 0) {
                c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                //XXX: I don't yet understand how to handle return errors that aren't in main().
                //return error.SDLRenderCopyFailed;
            }
            current.x += @as(f32, @floatFromInt(self.char_width));
        }
        StaticCounter.i += 0.1;
    }

    pub fn bounce(self: Font, string: []const u8, position: c.SDL_Point) void {
        const StaticCounter = struct {
            var i: f32 = 0.0;
        };

        var current: c.SDL_FPoint = c.SDL_FPoint{ .y = @as(f32, @floatFromInt(position.y)) - @abs(@sin(StaticCounter.i)) * 16, .x = @as(f32, @floatFromInt(position.x)) };

        for (string) |char| {
            var r: c.SDL_FRect = c.SDL_FRect{
                .x = current.x,
                .y = current.y,
                .w = @as(f32, @floatFromInt(self.char_width)),
                .h = @as(f32, @floatFromInt(self.char_height)),
            };

            if (c.SDL_RenderCopyF(self.renderer, self.texture, &self.char_rects[char], &r) != 0) {
                c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                //XXX: I don't yet understand how to handle return errors that aren't in main().
                //return error.SDLRenderCopyFailed;
            }
            current.x += @as(f32, @floatFromInt(self.char_width));
        }
        StaticCounter.i += 0.1;
    }

    pub fn swing(self: Font, string: []const u8, position: c.SDL_Point) void {
        const StaticCounter = struct {
            var i: f32 = 0.0;
        };

        var current: c.SDL_FPoint = c.SDL_FPoint{ .x = @as(f32, @floatFromInt(position.x)) + @sin(StaticCounter.i) * 160.0, .y = @as(f32, @floatFromInt(position.y)) };

        for (string) |char| {
            var r: c.SDL_FRect = c.SDL_FRect{
                .x = current.x,
                .y = current.y,
                .w = @as(f32, @floatFromInt(self.char_width)),
                .h = @as(f32, @floatFromInt(self.char_height)),
            };

            if (c.SDL_RenderCopyF(self.renderer, self.texture, &self.char_rects[char], &r) != 0) {
                c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                //XXX: I don't yet understand how to handle return errors that aren't in main().
                //return error.SDLRenderCopyFailed;
            }
            current.x += @as(f32, @floatFromInt(self.char_width));
        }
        StaticCounter.i += 0.02;
    }

    pub fn sine(self: Font, string: []const u8, position: c.SDL_Point) void {
        const string_width: usize = string.len * self.char_width;
        const StaticCounter = struct {
            var i: f32 = 0.0;
        };

        var current: c.SDL_FPoint = c.SDL_FPoint{ .x = @as(f32, @floatFromInt(k_screen_width)) - StaticCounter.i, .y = @as(f32, @floatFromInt(position.y)) };

        if (-(@as(f32, @floatFromInt(string_width + k_screen_width))) >= current.x) {
            StaticCounter.i = 0.0;
        }

        for (string) |char| {
            var r: c.SDL_FRect = c.SDL_FRect{
                .x = current.x,
                .y = current.y + @sin(current.x * 0.05 + 200) * 20,
                .w = @as(f32, @floatFromInt(self.char_width)),
                .h = @as(f32, @floatFromInt(self.char_height)),
            };

            if (c.SDL_RenderCopyF(self.renderer, self.texture, &self.char_rects[char], &r) != 0) {
                c.SDL_Log("Unable to copy a portion of the texture to the current rendering target: %s", c.SDL_GetError());
                //XXX: I don't yet understand how to handle return errors that aren't in main().
                //return error.SDLRenderCopyFailed;
            }
            current.x += @as(f32, @floatFromInt(self.char_width));
            StaticCounter.i += 0.1;
        }
    }
};

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
    g_font = Font.init(g_renderer, @embedFile("vp16.png"), 16, 16);
}

fn game_update() void {
    g_font.bounce("bounce()", c.SDL_Point{ .x = 0, .y = 16 });
    g_font.shake("shake()", c.SDL_Point{ .x = 0, .y = 16 * 3 });
    g_font.sine("sine()", c.SDL_Point{ .x = 0, .y = 16 * 5 });
    g_font.static("static()", c.SDL_Point{ .x = 0, .y = 16 * 7 });
    g_font.static_sine("static_sine()", c.SDL_Point{ .x = 0, .y = 16 * 9 });
    g_font.swing("swing()", c.SDL_Point{ .x = (k_screen_width / 2) - (7 * 16) / 2, .y = 16 * 11 });
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

    g_window = c.SDL_CreateWindow("Zig + SDL2 bitmap font showcase", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, k_screen_width, k_screen_height, c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI) orelse
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

    if (c.SDL_RenderSetIntegerScale(g_renderer, c.SDL_TRUE) != 0) {
        c.SDL_Log("Unable to force integer scale for resolution-independent rendering: %s", c.SDL_GetError());
        //XXX: Not sure if execution should stop because of that.
        //return error.SDLRenderSetIntegerScaleFailed;
    }

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
