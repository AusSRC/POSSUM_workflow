#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include {
    get_complete_tiles as get_complete_tiles;
} from './modules/get_complete_tiles'
//include { rename_tiles } from './modules/rename_tiles'
include { mosaicking } from './modules/mosaicking'

workflow {
    tile_map = file("${params.HPX_TILE_MAP}")

    main:
        get_complete_tiles(tile_map, "u")
        mosaicking(
            get_complete_tiles.out.tile_ids.flatten(),
            get_complete_tiles.out.id_to_files,
            "u")
        //rename_tiles(
        //    mosaicking.out.tile_id,
        //    mosaicking.out.mosaic,
        //    mosaicking.out.mosaic_weights
        //)
}