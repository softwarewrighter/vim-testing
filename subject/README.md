# subject/

Where the plugin under test goes. **Everything in here is gitignored.**

The vimgem plugin is distributed as a `.tgz` by its author (Russ Tremain)
and is not vendored in this repo — publishing it is his call, not ours.
This directory is the drop point:

```sh
cp ~/tools/russt/vimgem_0.1.260827_nopack.tgz subject/
./install.sh subject/vimgem_0.1.260827_nopack.tgz
```

`install.sh --mode sandbox` (the default) also unpacks each build to
`subject/vimfiles-<version>/`, so several releases can sit here side by
side and be A/B'd without any of them touching `~/.vim`.
