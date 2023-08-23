#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process download {
    executor = 'local'
    container = params.CASDA_DOWNLOAD_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return 'retry' }
    maxErrors 10

    input:
        val sbid

    output:
        val "${params.WORKDIR}/$sbid/${sbid}.json", emit: manifest

    script:
        """
        #!/bin/bash
        if [ ! -f "${params.WORKDIR}/$sbid/${sbid}.json" ]; then
            python3 -u /app/casda_download.py \
                -s $sbid \
                -o ${params.WORKDIR}/$sbid \
                -c ${params.CASDA_CREDENTIALS} \
                -m ${params.WORKDIR}/$sbid/${sbid}.json \
                -p POSSUM
        fi
        """
}

import groovy.json.JsonSlurper

process parse_manifest {
    executor = 'local'

    input:
        val manifest

    output:
        val i_file, emit: i_file
        val q_file, emit: q_file
        val u_file, emit: u_file
        val weights_file, emit: weights_file
    
    exec:
        i_file = null
        q_file = null
        u_file = null
        weights_file = null

        def inputFile = new File("$manifest")
        def InputJSON = new JsonSlurper().parseText(inputFile.text)
        InputJSON.each {
            if (it.contains('image.restored.i.')) {
                i_file = it
            }
            else if (it.contains('image.restored.q.')) {
                q_file = it
            }
            else if (it.contains('image.restored.u.')) {
                u_file = it
            }
            else if (it.contains('weights.')) {
                weights_file = it
            }
        }
}


workflow download_casda {
    take:
        sbid

    main:
        download(sbid)
        parse_manifest(download.out.manifest)

    emit:
        i = parse_manifest.out.i_file
        q = parse_manifest.out.q_file
        u = parse_manifest.out.u_file
        weights = parse_manifest.out.weights_file
        sbid = sbid
}