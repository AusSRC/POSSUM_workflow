#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { mosaicking } from './modules/mosaicking'
include { get_pixel_set } from './modules/get_complete_tiles'
include { objectstore_download_component; objectstore_upload_pixel } from './modules/objectstore'

workflow {
    tile_id = "${params.TILE_ID}"
    obs_ids = "${params.OBS_IDS}"
    band = "${params.BAND}"
    check_subdir = 'survey/i/'
    component_dir = "${WORKDIR}/components"
    tile_dir = "${WORKDIR}/tiles"
    csv_out = "${WORKDIR}/config/${tile_id}.${band}.map.json"

    main:
        // Fetch from acacia if not on scratch
        objectstore_download_component(
            tile_id,
            obs_ids,
            component_dir,
            check_subdir
        )

        // Run mosaicking
        get_pixel_set(
            tile_id,
            obs_ids,
            band,
            component_dir,
            tile_dir,
            csv_out,
            objectstore_download_component.out.stdout
        )
        mosaicking(get_pixel_set.out.pixel_map)

        // Push complete tiles to acacia
        objectstore_upload_pixel(
            tile_id,
            band,
            tile_dir,
            mosaicking.out.mosaic_files
        )
}