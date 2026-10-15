#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { conv2d } from './modules/convolution'
include { hpx_tile_map } from './modules/hpx_tile_map'
include { tiling as tile_image; tiling as tile_weights; } from './modules/tiling'
include { download_emu; evaluation_files } from './modules/casda'
include { objectstore_upload_component; } from './modules/objectstore'
include { provenance as provenance_image; provenance as provenance_weights; } from './modules/metadata'

workflow {
    sbid = "${params.SBID}"
    band = "${params.BAND}"

    main:
        // Preprocessing (downloading images and metadata)
        download_emu(sbid)
        evaluation_files(sbid)

        // Convolution
        conv2d(download_emu.out.i_file, "i")

        // Tiling
        hpx_tile_map(sbid, conv2d.out.cube_conv, evaluation_files.out.evaluation_files, band)
        tile_image(sbid, hpx_tile_map.out.obs_id, conv2d.out.cube_conv, hpx_tile_map.out.tile_map, 'i')
        tile_weights(sbid, hpx_tile_map.out.obs_id, download_emu.out.weights_file, hpx_tile_map.out.tile_map, 'w')

        // Add provenance information
        provenance_image(sbid, hpx_tile_map.out.obs_id, "mfs", "i", tile_image.out.ready)
        provenance_weights(sbid, hpx_tile_map.out.obs_id, "mfs", "w", tile_weights.out.ready)

        // Upload
        objectstore_upload_component(provenance_image.out.combine(provenance_weights.out), hpx_tile_map.out.obs_id, "mfs")
}

