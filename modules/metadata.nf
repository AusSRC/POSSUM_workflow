#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process process_pixel_map {
    executor = 'local'

    input:
        val pixel

    output:
        val pixel_stokes_list, emit: pixel_stokes_list_out

    exec:
        pixel_stokes_list = pixel.getValue()
}

process parse_sbids_from_pixel_map {
    executor = 'local'

    input:
        val pixel_stokes

    output:
        val sbids_str, emit: sbids

    exec:
        def input_files = pixel_stokes.getValue().get('input')
        def get_sbid = { fn.split(".SB")[1].substring(0, 5) }
        def sbids = []
        input_files.eachWithIndex{ it, i -> sbids[i] = get_sbid(it) }
        sbids.sort()
        def sbids_str = sbids.join(' ')
}

process add_sbid_history_to_fits_header {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val mosaic_files
        val sbids

    output:
        val true, emit: ready

    script:
        def image = mosaic_files[0]
        def weights = mosaic_files[1]

        """
        #!/bin/bash

        python3 /app/add_to_fits_header.py \
            -i $image $weights \
            -k SBID HISTORY \
            -v $sbids "Pre-processed with the AusSRC POSSUM pipeline"
        """
}

workflow add_to_fits_header {
    take:
        mosaic_files
        pixel_map

    main:
        process_pixel_map(pixel_map.flatMap())
        parse_sbids_from_pixel_map(
            process_pixel_map.out.pixel_stokes_list_out.flatMap()
        )
        add_sbid_history_to_fits_header(
            mosaic_files,
            parse_sbids_from_pixel_map.out.sbids
        )
        ready = add_sbid_history_to_fits_header.out.ready

    emit:
        ready
}