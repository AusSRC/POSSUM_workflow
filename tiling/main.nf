#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Tiling
process generate_healpix_headers {
    container = params.POSSUM_TILING_COMPONENT
    containerOptions = '--bind /mnt/shared:/mnt/shared'

    input:
        val image_cube

    output:
        stdout emit: stdout

    script:
        """
        python3 -u /app/healpix_headers.py \
            -i "$image_cube" \
            -o ${params.WORKDIR}/${params.TILING_OUTPUT_DIRECTORY} \
            -n ${params.NSIDE}
        """
}

// Get generated image cube files into channel
process get_healpix_header_files {
    executor = 'local'

    input:
        val generate_healpix_headers

    output:
        val header_files, emit: header_files

    exec:
        header_files = file("${params.WORKDIR}/${params.TILING_OUTPUT_DIRECTORY}/*.hdr")
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow tiling {
    take: image_cube

    main:
        generate_healpix_headers(image_cube)
        get_healpix_header_files(generate_healpix_headers.out.stdout)
        get_healpix_header_files.out.header_files.view()
}

// ----------------------------------------------------------------------------------------

