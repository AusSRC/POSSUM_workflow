#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include {
    get_complete_tiles as get_complete_tiles_i;
    get_complete_tiles as get_complete_tiles_w;
} from './modules/get_complete_tiles'
include { mosaicking } from './modules/mosaicking'

workflow {
    tile_map = file("${params.HPX_TILE_MAP}")

    main:
        get_complete_tiles_i(tile_map, "i")
        get_complete_tiles_w(tile_map, "w")
        mosaicking(
            get_complete_tiles_i.out.tile_ids.flatten(),
            get_complete_tiles_i.out.id_to_files,
            get_complete_tiles_w.out.id_to_files,
            "i"
        )
}