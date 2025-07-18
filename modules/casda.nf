#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process download_cubes {
    container = params.CASDA_DOWNLOAD_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} --bind /home:/home"

    errorStrategy { sleep(Math.pow(3, task.attempt) * 200 as long); return 'retry' }
    maxErrors 3

    input:
        val sbid
        val project
        val manifest

    output:
        val "$manifest", emit: manifest
        val true, emit: done

    script:
        """
        #!/bin/bash

        if [ ! -f "$manifest" ]; then
            python3 -u /app/casda_download.py \
                -s $sbid \
                -o ${params.WORKDIR}/sbid_processing/$sbid \
                -c ${params.CASDA_CREDENTIALS} \
                -m $manifest \
                -p $project
        fi
        """
}

process download_evaluation_files {
    container = params.CASDA_DOWNLOAD_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} --bind /home:/home"

    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return 'retry' }
    maxErrors 3

    input:
        val sbid

    output:
        val "${params.WORKDIR}/sbid_processing/$sbid/${params.EVALUATION_FILES_DIR}", emit: evaluation_files

    script:
        """
        #!/bin/bash

        python3 /app/evaluation_files.py -s $sbid \
            -p AS203 \
            -o ${params.WORKDIR}/sbid_processing/$sbid/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}

        python3 /app/evaluation_files.py \
            -s $sbid \
            -p AS202 \
            -o ${params.WORKDIR}/sbid_processing/$sbid/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}

        python3 /app/evaluation_files.py \
            -s $sbid \
            -p AS201 \
            -o ${params.WORKDIR}/sbid_processing/$sbid/${params.EVALUATION_FILES_DIR} \
            -c ${params.CASDA_CREDENTIALS}
        """
}

import groovy.json.JsonSlurper
process parse_possum_manifest {
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

        if (i_file == null) {
            throw new Exception("stokes i file is not found")
        }

        if (q_file == null) {
            throw new Exception("stokes q file is not found")
        }

        if (u_file == null) {
            throw new Exception("stokes u file is not found")
        }

        if (weights_file == null) {
            throw new Exception("weights file is not found")
        }
}

process parse_emu_manifest {
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

        if (i_file == null) {
            throw new Exception("stokes i file is not found")
        }

        if (weights_file == null) {
            throw new Exception("weights file is not found")
        }
}
