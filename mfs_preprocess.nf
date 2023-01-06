#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { get_evaluation_files } from './modules/get_evaluation_files'
include { conv2d } from './modules/convolution'
include { hpx_tile_map } from './modules/hpx_tile_map'
include {
    tiling as tile_image;
    tiling as tile_weights;
} from './modules/tiling'

workflow {
    sbid = "${params.SBID}"
    i_cube = "${params.I_CUBE}"
    weights = "${params.WEIGHTS_CUBE}"

    main:
        get_evaluation_files(sbid)
        conv2d(i_cube, "i")
        hpx_tile_map(sbid, conv2d.out.cube_conv, get_evaluation_files.out.evaluation_files)
        tile_image(sbid, hpx_tile_map.out.obs_id, conv2d.out.cube_conv, hpx_tile_map.out.tile_map, 'i')
        tile_weights(sbid, hpx_tile_map.out.obs_id, weights, hpx_tile_map.out.tile_map, 'w')
}