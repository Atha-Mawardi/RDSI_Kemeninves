# Berkas proyek tinggal di folder kode BKPM.
# Path skrip dihitung dari akar repositori (01 Data, 02 Code).
# RStudio menaruh direktori kerja di folder proyek sesudah berkas ini dibaca.
# Kait di bawah mengembalikannya ke akar setelah sesi siap.

setHook("rstudio.sessionInit", function(newSession) {
  if (!isTRUE(newSession)) return(invisible(NULL))
  proyek <- getwd()
  akar <- normalizePath(file.path(proyek, "..", ".."), winslash = "/", mustWork = FALSE)
  if (file.exists(file.path(proyek, "2026bkpm.Rproj")) &&
      dir.exists(file.path(akar, "01 Data"))) {
    setwd(akar)
  }
}, action = "append")
