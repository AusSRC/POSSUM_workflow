#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process download_singularity {
    executor = 'local'
    debug true


    output:
        val true, emit: ready

    shell:
        '''
        #!/bin/bash

        lock_acquire() {
            # Open a file descriptor to lock file
            exec {LOCKFD}>!{params.SINGULARITY_CACHEDIR}/container.lock || return 1

            # Block until an exclusive lock can be obtained on the file descriptor
            flock -x $LOCKFD
        }

        lock_release() {
            test "$LOCKFD" || return 1

            # Close lock file descriptor, thereby releasing exclusive lock
            exec {LOCKFD}>&- && unset LOCKFD
        }

        lock_acquire || { echo >&2 "Error: failed to acquire lock"; exit 1; }

        singularity pull !{params.SINGULARITY_CACHEDIR}/!{params.LINMOS_IMAGE_NAME}.img docker://!{params.LINMOS_IMAGE}

        lock_release
        '''
}


// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow download_containers {
    take:

    main:
        download_singularity()

    emit:
        ready = download_singularity.out.ready
}
