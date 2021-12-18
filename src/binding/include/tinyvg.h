#ifndef TINYVG_HEADER_GUARD
#define TINYVG_HEADER_GUARD

#include <stddef.h>
#include <stdint.h>

enum tinyvg_Error
{
  TINYVG_SUCCESS = 0,           // No error happened
  TINYVG_ERR_OUT_OF_MEMORY = 1, // An allocation failed during the process
  TINYVG_ERR_IO = 2,            // There was an I/O error
  TINYVG_ERR_INVALID_DATA = 3,  // The file format is not recognized and contains invalid data
  TINYVG_ERR_UNSUPPORTED = 4,   // The file format is recognized, but has an unsupported feature
};

//! Level of anti-aliasing applied to a rendered image.
enum tinyvg_AntiAlias
{
  TINYVG_AA_NONE = 1,
  TINYVG_AA_X4 = 2,
  TINYVG_AA_X9 = 3,
  TINYVG_AA_x16 = 4,
  TINYVG_AA_x25 = 6,
  TINYVG_AA_x49 = 7,
  TINYVG_AA_x64 = 8,
};

//! A output stream that can receive chunks of bytes.
struct tinyvg_OutStream
{
  //! generic purpose context for user data
  void * context;

  //! the write function will be called for each chunk written.
  enum tinyvg_Error (*write)(
    void * context,         // the context of the stream
    uint8_t const * buffer, // source data that should be written
    size_t length,          // length of `buffer` in bytes
    size_t * written        // A pointer that receives the number of bytes written. Write this in case of success. 
  );
};

//! A RGBA bitmap.
struct tinyvg_Bitmap
{
  uint32_t width;
  uint32_t height;
  //! Row-major pixel data, organized in (R,G,B,A) tuples, so the stride is `4 * width`.
  uint8_t * pixels;
};

//! Renders the TinyVG graphic into a SVG file.
enum tinyvg_Error tinyvg_render_svg(
  uint8_t const * tvg_data,              // Pointer to the TinyVG data
  size_t tvg_length,                     // Length of `tvg_data` in bytes.
  struct tinyvg_OutStream const * target // A stream that receives the output text in chunks.
);

//! Renders the TinyVG graphic into a RGBA bitmap.
enum tinyvg_Error tinyvg_render_bitmap(
  uint8_t const * tvg_data,         // Pointer to the TinyVG data
  size_t tvg_length,                // Length of `tvg_data` in bytes.
  enum tinyvg_AntiAlias anti_alias, // Strength of the anti-aliasing. `TINYVG_AA_NONE` means no anti aliasing, `TINYVG_AA_X4` means 2*2 super sampling, ...
  uint32_t width,                   // Width of the resulting image. If 0, will be automatically determined by the source file (retaining aspect) 
  uint32_t height,                  // Height of the resulting image. If 0, will be automatically determined by the source file (retaining aspect)
  struct tinyvg_Bitmap * bitmap     // If successful, `bitmap` will be filled with 
);

//! Releases the memory previously allocated by `tinyvg_render_bitmap`.
void tinyvg_free_bitmap(struct tinyvg_Bitmap * bitmap);

#ifndef TINYVG_NO_EXPORT_TYPES
typedef enum tinyvg_Error tinyvg_Error;
typedef enum tinyvg_AntiAlias tinyvg_AntiAlias;
typedef struct tinyvg_OutStream tinyvg_OutStream;
typedef struct tinyvg_Bitmap tinyvg_Bitmap;
#endif

#endif 
