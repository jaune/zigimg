//! this module implements the JFIF header
//! specified in https://www.w3.org/Graphics/JPEG/itu-t81.pdf 
//! section B.2.1 and assumes that there will be an application0 segment.

const std = @import("std");

const Image = @import("../../Image.zig");
const Markers = @import("./utils.zig").Markers;

const Self = @This();

/// see https://www.ecma-international.org/wp-content/uploads/ECMA_TR-98_1st_edition_june_2009.pdf
/// chapt 10.
pub const DensityUnit = enum(u8) {
    pixels = 0,
    dots_per_inch = 1,
    dots_per_cm = 2,
};

jfif_revision: u16,
density_unit: DensityUnit,
x_density: u16,
y_density: u16,

pub fn read(stream: *Image.Stream) !Self {
    // Read the first APP0 header.
    const reader = stream.reader();
    try stream.seekTo(2);
    const maybe_app0_marker = try reader.readIntBig(u16);
    if (maybe_app0_marker != @intFromEnum(Markers.application0)) {
        return error.App0MarkerDoesNotExist;
    }

    // Header length
    _ = try reader.readIntBig(u16);

    var identifier_buffer: [4]u8 = undefined;
    _ = try reader.read(identifier_buffer[0..]);

    if (!std.mem.eql(u8, identifier_buffer[0..], "JFIF")) {
        return error.JfifIdentifierNotSet;
    }

    // NUL byte after JFIF
    _ = try reader.readByte();

    const jfif_revision = try reader.readIntBig(u16);
    const density_unit: DensityUnit = @enumFromInt(try reader.readByte());
    const x_density = try reader.readIntBig(u16);
    const y_density = try reader.readIntBig(u16);

    const thumbnailWidth = try reader.readByte();
    const thumbnailHeight = try reader.readByte();

    if (thumbnailWidth != 0 or thumbnailHeight != 0) {
        // TODO: Support thumbnails (not important)
        return error.ThumbnailImagesUnsupported;
    }

    // Make sure there are no application markers after us.
    // TODO: Support application markers, present in versions 1.02 and above.
    // see https://www.ecma-international.org/wp-content/uploads/ECMA_TR-98_1st_edition_june_2009.pdf
    // chapt 10.1
    if (((try reader.readIntBig(u16)) & 0xFFF0) == @intFromEnum(Markers.application0)) {
        return error.ExtraneousApplicationMarker;
    }

    try stream.seekBy(-2);

    return Self{
        .jfif_revision = jfif_revision,
        .density_unit = density_unit,
        .x_density = x_density,
        .y_density = y_density,
    };
}