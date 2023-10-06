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
        val project
        val manifest

    output:
        val "$manifest", emit: manifest

    script:
        """
        #!/bin/bash
        if [ ! -f "$manifest" ]; then
            python3 -u /app/casda_download.py \
                -s $sbid \
                -o ${params.WORKDIR}/$sbid \
                -c ${params.CASDA_CREDENTIALS} \
                -m $manifest \
                -p $project
        fi
        """
}

import groovy.json.JsonSlurper

process parse_possum_manifest {
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


process parse_emu_manifest {
    executor = 'local'

    input:
        val manifest

    output:
        val i_file, emit: i_file
        val weights_file, emit: weights_file

    exec:
        i_file = null
        weights_file = null

        def inputFile = new File("$manifest")
        def InputJSON = new JsonSlurper().parseText(inputFile.text)
        InputJSON.each {
            if (it.matches('(.*)image.i.(.*).cont.taylor.0.restored.conv.fits')) {
                i_file = it
            }
            else if (it.matches('(.*)weights.i.(.*).cont.taylor.0.(.*)')) {
                weights_file = it
            }
        }
}


workflow download_possum {
    take:
        sbid
        project
        manifest

    main:
        download(sbid, project, manifest)
        parse_possum_manifest(download.out.manifest)

    emit:
        i = parse_possum_manifest.out.i_file
        q = parse_possum_manifest.out.q_file
        u = parse_possum_manifest.out.u_file
        weights = parse_possum_manifest.out.weights_file
        sbid = sbid
}