#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { get_evaluation_files } from './modules/get_evaluation_files'
include { conv2d } from './modules/convolution'
include { hpx_tile_map } from './modules/hpx_tile_map'
include { tiling as tile_image; tiling as tile_weights; } from './modules/tiling'
include { download; parse_emu_manifest; } from "./modules/casda.nf"
include { objectstore_upload_component; } from './modules/objectstore'
include { provenance as provenance_image; provenance as provenance_weights; } from './modules/metadata'

workflow {
    sbid = "${params.SBID}"

    main:
        download(sbid, "EMU", "${params.WORKDIR}/sbid_processing/$sbid/mfs/${sbid}.json")

        parse_emu_manifest(download.out.manifest)

        get_evaluation_files(sbid)

        conv2d(parse_emu_manifest.out.i_file, "i")

        hpx_tile_map(sbid,
                     conv2d.out.cube_conv,
                     get_evaluation_files.out.evaluation_files)

        tile_image(sbid,
                   hpx_tile_map.out.obs_id,
                   conv2d.out.cube_conv,
                   hpx_tile_map.out.tile_map,
                   'i')

        tile_weights(sbid,
                     hpx_tile_map.out.obs_id,
                     parse_emu_manifest.out.weights_file,
                     hpx_tile_map.out.tile_map,
                     'w')

        provenance_image(sbid, hpx_tile_map.out.obs_id, "mfs", "i", tile_image.out.ready)
        provenance_weights(sbid, hpx_tile_map.out.obs_id, "mfs", "w", tile_weights.out.ready)

        objectstore_upload_component(
            provenance_image.out.combine(provenance_weights.out),
            hpx_tile_map.out.obs_id,
            "mfs"
        )
}

