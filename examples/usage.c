#include <stdio.h>
#include <stdbool.h>
#include <tinyvg.h>

unsigned char shield_tvg[] = {
  0x72, 0x56, 0x01, 0x42, 0x18, 0x18, 0x02, 0x29, 0xad, 0xff, 0xff, 0xff,
  0xf1, 0xe8, 0xff, 0x03, 0x02, 0x00, 0x04, 0x05, 0x03, 0x30, 0x04, 0x00,
  0x0c, 0x14, 0x02, 0x2c, 0x03, 0x0c, 0x42, 0x1b, 0x57, 0x30, 0x5c, 0x03,
  0x45, 0x57, 0x54, 0x42, 0x54, 0x2c, 0x02, 0x14, 0x45, 0x44, 0x03, 0x40,
  0x4b, 0x38, 0x51, 0x30, 0x54, 0x03, 0x28, 0x51, 0x20, 0x4b, 0x1b, 0x44,
  0x03, 0x1a, 0x42, 0x19, 0x40, 0x18, 0x3e, 0x03, 0x18, 0x37, 0x23, 0x32,
  0x30, 0x32, 0x03, 0x3d, 0x32, 0x48, 0x37, 0x48, 0x3e, 0x03, 0x47, 0x40,
  0x46, 0x42, 0x45, 0x44, 0x30, 0x14, 0x03, 0x36, 0x14, 0x3c, 0x19, 0x3c,
  0x20, 0x03, 0x3c, 0x26, 0x37, 0x2c, 0x30, 0x2c, 0x03, 0x2a, 0x2c, 0x24,
  0x27, 0x24, 0x20, 0x03, 0x24, 0x1a, 0x29, 0x14, 0x30, 0x14, 0x00
};
unsigned int shield_tvg_len = 119;

tinyvg_Error writeToFile(void * ctx, uint8_t const * data, size_t length, size_t * written);

bool saveTga(char const * file_name, tinyvg_Bitmap const * bitmap);

int main() 
{
  tinyvg_Error err;

  FILE * f = fopen("output.svg", "w");
  if(f == NULL) {
    return 0;
  }
  err = tinyvg_render_svg(shield_tvg, shield_tvg_len, &(tinyvg_OutStream) {
    .context = f,
    .write = writeToFile,
  });
  fclose(f);
  if(err != TINYVG_SUCCESS) {
    return 1;
  }
  
  tinyvg_Bitmap bitmap;
  err = tinyvg_render_bitmap(shield_tvg, shield_tvg_len, TINYVG_AA_X9, 24, 24, &bitmap);
  if(err != TINYVG_SUCCESS) {
    return 1;
  }
  
  // Swap R and B pixel colors as TGA expects BGRA instead of RGBA
  for(size_t i = 0; i < (size_t)bitmap.width * (size_t)bitmap.height; i++)
  {
    uint8_t b = bitmap.pixels[4 * i + 0];
    uint8_t r = bitmap.pixels[4 * i + 2];
    bitmap.pixels[4 * i + 0] = r;
    bitmap.pixels[4 * i + 2] = b;
  }

  bool success = saveTga("output.tga", &bitmap);

  tinyvg_free_bitmap(&bitmap);

  if(!success) {
    return 1;
  }

  return 0;
}

tinyvg_Error writeToFile(void * ctx, uint8_t const * data, size_t length, size_t * written)
{
  *written = fwrite(data, 1, length, (FILE*)ctx);
  if(*written == 0)
    return TINYVG_ERR_IO;
  return TINYVG_SUCCESS;
}

bool saveTga(char const * file_name, tinyvg_Bitmap const * bitmap)
{
  FILE * f = fopen(file_name, "wb");
  if(f == NULL) {
    return false;
  }
  uint8_t tga_header[] =  {
    6, // image id len
    0, // color map type = no color map
    2, // image type = uncompressed true-color image

    // color map spec
    0, 0, // first index
    0, 0, // length
    0,    // // number of bits per pixel

    // image spec
    0, 0,     // x origin
    0, 0,     // y origin
    (bitmap->width & 0xFF),  ((bitmap->width >> 8) & 0xFF),   // width
    (bitmap->height & 0xFF), ((bitmap->height >> 8) & 0xFF), // height
    32,       // bits per pixel
    8 | 0x20, // 0…3 => alpha channel depth = 8, 4…7 => direction=top left

    // image id
    'T', 'i', 'n', 'y', 'V', 'G', 

    // color map
    // (empty)
  };
  fwrite(tga_header, sizeof(tga_header), 1, f);
  fwrite(bitmap->pixels, 4 * bitmap->width, bitmap->height, f);
  fclose(f);
  return true;
}