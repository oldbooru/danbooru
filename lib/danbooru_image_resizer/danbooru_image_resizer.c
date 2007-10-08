#include <ruby.h>
#include <gd.h>
#include <stdio.h>
#include <string.h>

#define DANBOORU_PREVIEW_SIZE 150

static VALUE danbooru_module;
static FILE * resizer_log = NULL;

/*
 * PRE-CONDITIONS:
 * 1) file_ext is one of three possible strings: jpg, gif, or png.
 *
 * 2) read_path is an absolute file path readable by Ruby, pointing to an 
 *    image of one of the above three mime types.
 *
 * 3) write_path is an absolute file path writable by Ruby, where the
 *    generated preview file will be written.
 *
 * POST-CONDITIONS:
 * 1) If no errors were encountered, a JPEG image will be written to the 
 *    write_path. This image will represent a thumbnail view of the file 
 *    given in read_path. The Ruby global constant true will be returned.
 *
 * 2) If any error occurred, the Ruby global constant false will be
 *    returned.
 */

static VALUE danbooru_resize_image(VALUE module, VALUE file_ext, VALUE read_path, VALUE write_path) {
  fprintf(resizer_log, "Entering danbooru_resize_image\n");

  VALUE file_ext_string = StringValue(file_ext);
  VALUE read_path_string = StringValue(read_path);
  VALUE write_path_string = StringValue(write_path);
  
  const char * file_ext_cstr = RSTRING(file_ext_string)->ptr;
  const char * read_path_cstr = RSTRING(read_path_string)->ptr;
  const char * write_path_cstr = RSTRING(write_path_string)->ptr;

  if (file_ext_cstr == NULL || read_path_cstr == NULL || write_path_cstr == NULL) {
    return Qfalse;
  }

  fprintf(resizer_log, "ext=%s read=%s write=%s\n", file_ext_cstr, read_path_cstr, write_path_cstr);
  
  FILE * read_file = fopen(read_path_cstr, "rb");
  
  if (read_file == NULL) {
    return Qfalse;
  }
  
  FILE * write_file = fopen(write_path_cstr, "wb");
  
  if (write_file == NULL) {
    fclose(read_file);
    return Qfalse;
  }

  fprintf(resizer_log, "Opened image files\n");
  
  gdImagePtr img = NULL;
  
  if (!strcmp(file_ext_cstr, "jpg")) {
    img = gdImageCreateFromJpeg(read_file);
  } else if (!strcmp(file_ext_cstr, "gif")) {
    img = gdImageCreateFromGif(read_file);
  } else if (!strcmp(file_ext_cstr, "png")) {
    img = gdImageCreateFromPng(read_file);
  }

  if (img == NULL) {
    fprintf(resizer_log, "Error loading image\n");
    fclose(read_file);
    fclose(write_file);
    fflush(resizer_log);
    return Qfalse;
  } else {
    fprintf(resizer_log, "Loaded image\n");
  }

  size_t width = img->sx;
	size_t height = img->sy;
	size_t max = (width > height) ? width : height;
	double scale = (max < DANBOORU_PREVIEW_SIZE) ? 1 : (double)DANBOORU_PREVIEW_SIZE / (double)max;
	width = width * scale;
	height = height * scale;

	gdImagePtr preview = gdImageCreateTrueColor(width, height);
	gdImageCopyResampled(preview, img, 0, 0, 0, 0, width, height, img->sx, img->sy);
  fprintf(resizer_log, "Generated preview\n");

	gdImageJpeg(preview, write_file, 95);
  fprintf(resizer_log, "Wrote preview file\n");

	gdImageDestroy(img);
	gdImageDestroy(preview);
	fclose(read_file);
	fclose(write_file);
	
  fprintf(resizer_log, "Cleaning up\n");
  fprintf(resizer_log, "-----\n");
  fflush(resizer_log);
  return Qtrue;
}

void Init_danbooru_image_resizer() {
  resizer_log = fopen("resizer.log", "w");
  danbooru_module = rb_define_module("Danbooru");
  rb_define_module_function(danbooru_module, "resize_image", danbooru_resize_image, 3);
}
