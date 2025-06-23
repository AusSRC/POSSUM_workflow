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

process get_component_files {
    executor = 'local'
    debug true

    input:
        val obs_id
        val subdir
        val stokes
        val ready

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

process compress {
    input:
        val files
        val ready

    output:
        val true, emit: ready

    script:
        """
        #!/bin/bash
        gzip -f $files
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
        get_component_files(obs_id, subdir, stokes, ready)
        add_history_to_fits_header(get_component_files.out.files_str, sbid, obs_id, subdir, stokes)
        compress(get_component_files.out.files_str, add_history_to_fits_header.out.ready)
        ready = compress.out.ready

    emit:
        ready
}
