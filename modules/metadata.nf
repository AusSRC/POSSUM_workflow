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

process get_component_files {
    executor = 'local'
    debug true

    input:
        val obs_id
        val subdir
        val stokes

    output:
        val files_str, emit: files_str

    exec:
        path = "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/${obs_id}/${subdir}/${stokes}"
        dir = new File(path)
        files_list = []
        dir.eachFileMatch (~/.*fits/) { file ->
            files_list << file.path
        }
        files_list.sort()
        files_str = files_list.join(" ")
}

process add_history_to_fits_header {
    container = params.METADATA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"
    debug true

    input:
        val files
        val sbid
        val obs_id
        val subdir
        val stokes

    output:
        val true, emit: ready

    script:
        """
        #!/bin/bash

        python3 /app/fits_history.py \
            -f $files -v \
            "AusSRC POSSUM pipeline START" \
            "$obs_id" \
            "$sbid" \
            "${workflow.repository} - ${workflow.revision} [${workflow.commitId}]" \
            "${workflow.commandLine}" \
            "${workflow.start}" \
            "Austin Shen (austin.shen@csiro.au)" \
            "AusSRC POSSUM pipeline END" \
        """
}

workflow provenance {
    take:
        sbid
        obs_id
        subdir
        stokes
        ready

    main:
        get_component_files(obs_id, subdir, stokes)
        add_history_to_fits_header(get_component_files.out.files_str, sbid, obs_id, subdir, stokes)
        ready = add_history_to_fits_header.out.ready

    emit:
        ready
}
