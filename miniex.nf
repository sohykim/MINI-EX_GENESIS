#!/usr/bin/env nextflow

nextflow.preview.dsl=2
/*
=====================================================
		MINI-EX
=====================================================
Motif-Informed Network Inference from gene EXpression

-----------------------------------------------------
*/

log.info """\
         Motif-Informed Network Inference from gene EXpression
         =====================================================
         """
         .stripIndent()
		 
grnboostOutput = "$baseDir/example/OUTPUTS/GRNBoost2_output"
regOutput = "$baseDir/example/OUTPUTS/regulons_output"
GOenrichmentOutput = "$baseDir/example/OUTPUTS/GOenrichment_output"
figs = "$baseDir/example/OUTPUTS/figures"


process run_grnboost {
	
	module 'python/x86_64/3.6.5'
	publishDir grnboostOutput, mode: 'copy'

    input:
	path script_grnboost
	path TF_list
	tuple val(dataset_id), path(matrix)
	
	output:
	tuple val("${dataset_id}"), path("${dataset_id}_grnboost2.txt")

    """
    python3 $script_grnboost $TF_list "$matrix" 5 "${dataset_id}_grnboost2.txt"
    """
}

process unzip_motifMappings {
	
    input:
	path ff_motifs

	output:
	path "MotifMappings.csv"

    """
    gunzip -c $ff_motifs > "MotifMappings.csv"
	
    """
}

process run_enricher_motifs {
	
    input:
	path script_enricher
	path ff_motifs_unzipped
	tuple val(dataset_id), path(modules)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_enricherRegulons.txt")

    """
	
    $script_enricher $ff_motifs_unzipped "$modules" -f 0.001 --print-hits -o "${dataset_id}_enricherRegulons.txt"
    """
}

process filter_motifs {
	
	module 'python/x86_64/3.6.5'

    input:
	path script_motifs
	path infoTF
	val motifFilter
	tuple val(dataset_id), path(enrichedModules)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_enrichedRegulons.txt")
	
    """
    python3 $script_motifs $infoTF "$enrichedModules" "${dataset_id}_enrichedRegulons.txt" "$motifFilter"
    """
}

process get_topDEGs {

	module 'python/x86_64/3.6.5'
	
    input:
	path script_topDEGs
	val tops
	tuple val(dataset_id), path (allMarkers)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_top${tops}cellClusters.out")
	
    """
    python3 $script_topDEGs $allMarkers "$tops" "${dataset_id}_top${tops}cellClusters.out"
    """
}

process run_enricher_cluster {
	
    input:
	path script_enricher
	tuple val(dataset_id), path (ff_celltypes), path (filteredRegulons)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_enricherCelltypes.txt") 

    """
    $script_enricher $ff_celltypes "$filteredRegulons" -f 0.001 --print-hits -o "${dataset_id}_enricherCelltypes.txt"
    """
}

process filter_expression {
	
	module 'python/x86_64/3.6.5'
	publishDir regOutput, mode: 'copy'

    input:
	path script_expTFs
	path infoTF
	val expressionFilter
	tuple val(dataset_id), path (expMatrix), path (cellClusters), path (regulons)

	output:
    tuple val("${dataset_id}"), path("${dataset_id}_regulons.txt")
	

    """
    python3 $script_expTFs "$expMatrix" $infoTF $cellClusters "$expressionFilter" "$regulons" "${dataset_id}_regulons.txt"

    """
}

process clustermap_regs {

	module 'python/x86_64/3.6.5'
	publishDir figs, mode: 'copy'
	
    input:
	path script_clustermap
	tuple val(dataset_id), path (identClust), path (finalRegulons)


	output:
	tuple val("${dataset_id}"), path("${dataset_id}_clustermap.svg")
	 
    """
	python3 $script_clustermap "$identClust" "$finalRegulons" "${dataset_id}_clustermap.svg"

    """
}


process network_centrality {

	module 'python/x86_64/3.6.5'
	
    input:
	path script_networkCentrality
	tuple val(dataset_id), path (finalRegulons)

	output:
    tuple val("${dataset_id}"), path("${dataset_id}_networkCentrality.txt")
	

    """
    python3 $script_networkCentrality "$finalRegulons" "${dataset_id}_networkCentrality.txt"

    """
}

process getFiles_enrichment {

	module 'python/x86_64/3.6.5'
	
    input:
	path script_filesEnrichment
	path GOfile
	tuple val(dataset_id), path (finalRegulons)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_setFileRegulons.out"), path("${dataset_id}_featureFileGO.out")

    """
    python3 $script_filesEnrichment "$finalRegulons" "$GOfile" "${dataset_id}_setFileRegulons.out" "${dataset_id}_featureFileGO.out"

    """
}

process GO_enricher {

	module 'python/x86_64/3.6.5'
	publishDir GOenrichmentOutput, mode: 'copy'
	
    input:
	path script_enricher
	tuple val(dataset_id), path (s), path (f)
	
	output:
	tuple val("${dataset_id}"), path("${dataset_id}_enricherGO.txt")
	 
    """
    $script_enricher "$f" "$s" -f 0.05 -p -o "${dataset_id}_enricherGO.txt"
		
    """
}

process check_reference {

	module 'python/x86_64/3.6.5'
	
    input:
	path script_checkReference
	tuple val(dataset_id), path (finalRegulons)
	path GOfile
	path termsOfInterest

	output:
    tuple val("${dataset_id}"), stdout
	
    """
    python3 $script_checkReference "$finalRegulons" "$GOfile" "$termsOfInterest" 

    """
}

process ranking_df_ref {

	module 'python/x86_64/3.6.5'
	
    input:
	path script_makedfRef
	path alias
	path GOfile
	path termsOfInterest
	tuple val(dataset_id), path (identClust), path (finalRegulons), path (qvalct), path (netCent), path (enrichGO), path (allMarkers)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_dfForRanking.txt")
	 
	"""
	python3 $script_makedfRef "$identClust" "$finalRegulons" "$alias" "$qvalct" "$GOfile" "$termsOfInterest" "$netCent" "$enrichGO" "$allMarkers" "${dataset_id}_dfForRanking.txt"
	
	"""	 
}

process ranking_df_std {

	module 'python/x86_64/3.6.5'
	
    input:
	path script_makedfStd	
	path alias
	path GOfile
	tuple val(dataset_id), path (identClust), path (finalRegulons), path (qvalct), path (netCent), path (allMarkers)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_dfForRanking.txt")
	 
	"""
	python3 $script_makedfStd "$identClust" "$finalRegulons" "$alias" "$qvalct" "$GOfile" "$netCent" "$allMarkers" "${dataset_id}_dfForRanking.txt"
	"""	 
}


process makeBorda {

	module 'python/x86_64/3.6.5'
	publishDir regOutput, mode: 'copy'
	echo true
	
    input:
	path script_makeborda
	tuple val(dataset_id), path (regulonsDF), val(metrics), val(ref)

	output:
	tuple val("${dataset_id}"), path("${dataset_id}_rankedRegulons.xlsx")
	 
    """
	python3 $script_makeborda "$regulonsDF" "$metrics" "${dataset_id}_rankedRegulons.xlsx" "$ref"
		
    """
}


process heatmap_tops {

	module 'python/x86_64/3.6.5'
	publishDir figs, mode: 'copy'
	
    input:
	path script_heatmapTops
	tuple val(dataset_id), path (rankedRegulons)
	val topRegs

	output:
	tuple val(dataset_id), path("${dataset_id}_heatmapSpecificity.svg"), path("${dataset_id}_heatmapDEcalls.svg")
	 
    """
	python3 $script_heatmapTops "$rankedRegulons" "${dataset_id}_heatmapSpecificity.svg" "${dataset_id}_heatmapDEcalls.svg" "$topRegs"	
    """
}


workflow {

	matrix_ch = Channel.fromPath(params.expressionMatrix).map { n -> [ n.baseName.split("_")[0], n ] }	
	matrix_ch.view()
	run_grnboost(params.script_grnboost,params.TF_list,matrix_ch)

	unzip_motifMappings(params.featureFile_motifs)
	run_enricher_motifs(params.script_enricher,unzip_motifMappings.out,run_grnboost.out)
	
	filter_motifs(params.script_motifs,params.infoTF,params.motifFilter,run_enricher_motifs.out)
	
	deg_ch = Channel.fromPath(params.markersOut).map { n -> [ n.baseName.split("_")[0], n ] }
	
	get_topDEGs(params.script_topDEGs,params.tops,deg_ch)

	cluster_enrich_ch = get_topDEGs.out.join(filter_motifs.out)
	
	run_enricher_cluster(params.script_enricher,cluster_enrich_ch)	

	cluster_ch = Channel.fromPath(params.cell2clusters).map { n -> [ n.baseName.split("_")[0], n ] }
	filter_combined_ch = matrix_ch.join(cluster_ch).join(run_enricher_cluster.out)
	
	filter_expression(params.script_expTFs,params.infoTF,params.expressionFilter,filter_combined_ch)
		
	cluster_ids_ch = Channel.fromPath(params.cluster2ident).map { n -> [ n.baseName.split("_")[0], n ] }
	regulons_ident_ch = cluster_ids_ch.join(filter_expression.out)
	clustermap_regs(params.script_clustermap,regulons_ident_ch)
	
	network_centrality(params.script_networkCentrality,filter_expression.out)

	getFiles_enrichment(params.script_filesEnrichment,params.GOfile,filter_expression.out)
	GO_enricher(params.script_enricher,getFiles_enrichment.out)		

	if (params.termsOfInterest != null){		

		check_reference(params.script_checkReference,filter_expression.out,params.GOfile,params.termsOfInterest)
		check_reference_trimmed = check_reference.out.map { n,it -> [ n, it.trim() ] }
	
		rankingRef_combined_ch = cluster_ids_ch.join(filter_expression.out).join(run_enricher_cluster.out).join(network_centrality.out).join(GO_enricher.out).join(deg_ch)
		ranking_df_ref(params.script_makedfRef,params.alias,params.GOfile,params.termsOfInterest,rankingRef_combined_ch)
	
		metrics_ch = Channel.value('qval_cluster,out-degree,betweenness,closeness,GO_enrich_qval')
		metrics_combi_ch = ranking_df_ref.out.combine(metrics_ch).join(check_reference_trimmed)
		}
		
	if (params.termsOfInterest == null){
		
		rankingStd_combined_ch = cluster_ids_ch.join(filter_expression.out).join(run_enricher_cluster.out).join(network_centrality.out).join(deg_ch)
		ranking_df_std(params.script_makedfStd,params.alias,params.GOfile,rankingStd_combined_ch)
	
		metrics_ch = Channel.value('qval_cluster,out-degree,betweenness,closeness')
		std_ch = Channel.value('std')
		metrics_combi_ch = ranking_df_std.out.combine(metrics_ch).combine(std_ch)
		}
		
	makeBorda(params.script_makeborda,metrics_combi_ch)
		
	heatmap_tops(params.script_heatmapTops,makeBorda.out,params.topRegs)
}

workflow.onComplete {
	log.info ( workflow.success ? "Done!" : "Oops .. something went wrong" )
}