#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process objectstore_upload_component {
    input:
        val ready
        val obs_id
        val subdir

    script:
        """
        rclone --s3-chunk-size=128M --progress copy -u --ignore-checksum "${params.WORKDIR}/${params.TILE_COMPONENT_OUTPUT_DIR}/${obs_id}/${subdir}" "pawsey0980:possum/components/${obs_id}/${subdir}"
        """
}

process objectstore_download_component {
    input:
        val ready
        val tile_id
        val obs_ids
        val component_dir
        val check_subdir

    output:
        stdout emit: stdout

    script:
        """
        IFS=","
        obs_ids="${obs_ids}"
        for obs_id in \$obs_ids
        do
            if [ -z "\$(ls -A ${component_dir}/\$obs_id/${check_subdir})" ]; then
                rclone --s3-chunk-size=128M --progress copy -u --ignore-checksum --include="*${tile_id}*" "pawsey0980:possum/components/\$obs_id/survey" "${component_dir}/\$obs_id/survey"
            else
              exit 0
            fi
        done
        """
}

process objectstore_upload_pixel {
    input:
        val ready
        val tile_id
        val band
        val tile_dir

    script:
        """
        rclone --s3-chunk-size=128M --progress copy -u --ignore-checksum --include="*band${band}*${tile_id}* "${tile_dir}/${tile_id}" "pawsey0980:possum/tiles/${tile_id}"
        """
}