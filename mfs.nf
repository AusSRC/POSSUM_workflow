#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { get_evaluation_files } from './modules/get_evaluation_files'
include { conv2d } from './modules/conv2d'
include { hpx_tile_map } from './modules/hpx_tile_map'
include {
    tiling as tile_i;
    tiling as tile_w;
} from './modules/tiling'
include {
    get_complete_tiles as get_complete_tiles_i;
    get_complete_tiles as get_complete_tiles_w;
} from './modules/get_complete_tiles'
include { mosaicking } from './modules/mosaicking'

workflow {
    sbid = "${params.SBID}"
    i_cube = "${params.I_CUBE}"
    weights = "${params.WEIGHTS_CUBE}"

    main:
        get_evaluation_files(sbid)
        conv2d(i_cube, weights)
        hpx_tile_map(sbid, conv2d.out.cube_conv, get_evaluation_files.out.evaluation_files)

        // tile_i(sbid, conv2d.out.cube_conv, 'i', get_evaluation_files.out.evaluation_files)
        // tile_w(sbid, conv2d.out.weights_conv, 'w', get_evaluation_files.out.evaluation_files)
        // get_complete_tiles_i(tile_i.out.tiles, "i")
        // get_complete_tiles_w(tile_w.out.tiles, "w")
        // mosaicking(
        //     get_complete_tiles_i.out.tiles,
        //     get_complete_tiles_w.out.tiles,
        //     "i"
        // )
}