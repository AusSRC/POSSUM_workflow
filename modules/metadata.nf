#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process process_pixel_map {
    executor = 'local'
    debug true

    input:
	val ready
        val pixel

    output:
        val pixel_stokes_list, emit: pixel_stokes_list_out

    exec:
        pixel_stokes_list = pixel.getValue()
}

// NOTE: currently only works for MFS images
process parse_sbids_from_pixel_map {
    executor = 'local'
    debug true

    input:
        val pixel_stokes

    output:
        val sbids_str, emit: sbids

    exec:
        def input_files = pixel_stokes.getValue().get('input')[0]
        def get_sbid = { it.split('SB')[1].substring(0, 5) }
        def sbids = []
        for (f in input_files) {
            sbids.add(get_sbid(f))
	}
        sbids.sort()
        sbids_str = sbids.join(' ')
}

process add_history_to_fits_header {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"
    debug true

    input:
        val mosaic_files

    output:
        val true, emit: ready

    script:
        def image = mosaic_files[0]
        def weights = mosaic_files[1]

        """
        #!/bin/bash

        python3 /app/add_to_fits_header.py \
            -i ${image}.fits ${weights}.fits \
            -k HISTORY HISTORY \
            -v "Pre-processed with the AusSRC POSSUM pipeline" "${workflow.repository} - ${workflow.revision} [${workflow.commitId}]"
        """
}

workflow add_to_fits_header {
    take:
        mosaic_files
        pixel_map

    main:
        add_history_to_fits_header(mosaic_files)
        ready = add_history_to_fits_header.out.ready

    emit:
        ready
}
