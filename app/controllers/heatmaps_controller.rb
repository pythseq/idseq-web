class HeatmapsController < ApplicationController
  # TODO(tiago): remove by moving the needed modules to the model (or concern?)
  include PipelineRunsHelper

  TAXON_COUNTS_FIELDS_TO_PLUCK = [
    :tax_id,
    :genus_taxid,
    :count_type,
    :tax_level,
    :count,
    :percent_identity,
    :alignment_length,
    :e_value,
    :name,
    :is_phage,
  ].freeze

  TAXON_SUMMARIES_FIELDS_TO_PLUCK = [
    :tax_id,
    :mean,
    :stdev,
  ].freeze

  DEFAULT_BACKGROUND_ID = 93

  SKIP_CURRENT_HEATMAP = false

  def project
    count_type_param = params[:count_type]
    page_size = params[:page_size].to_i

    samples = current_power.project_samples(Project.find(params[:id]))

    timer_base = Timer.new("heatmap_study")

    # measure traditional heatmap for selected scenario
    #
    current_heatmap = {}
    unless SKIP_CURRENT_HEATMAP
      current_heatmap['nt'] = HeatmapHelper.fetch_top_taxons(samples, DEFAULT_BACKGROUND_ID, [], HeatmapHelper::READ_SPECIFICITY, false, page_size, 0, "highest_nt_rpm")
      timer_base.split("current_top_taxon_query_nt_sort")
      current_heatmap['nr'] = HeatmapHelper.fetch_top_taxons(samples, DEFAULT_BACKGROUND_ID, [], HeatmapHelper::READ_SPECIFICITY, false, page_size, 0, "highest_nr_rpm")
      timer_base.split("current_top_taxon_query_nr_sort")
    end

    pipeline_runs = get_succeeded_pipeline_runs_for_samples(samples)
    timer_base.split("fetch_pipelines")

    pipeline_runs = PipelineRun.joins(:taxon_counts).where(id: pipeline_runs.pluck(:id)).distinct
    timer_base.split("temp_removing prs_with_zero_taxon_counts")
    timer_base_results = timer_base.results

    count_types = count_type_param ? [count_type] : %w[NT NR]
    timer_results_by_count_type = {}
    taxon_counts_by_count_type = {}
    tax_ids_by_count_type = {}
    count_types.each do |count_type|
      timer_by_count_type = Timer.new("heatmap_study.#{count_type}")

      # samples 0
      one_taxon = fetch_taxon_counts(pipeline_runs.first, count_type, page_size)
      timer_by_count_type.split("single_fetch")

      # get first N (start with 100?) and sort by rpm
      # (test adding an index and measure)
      all_taxa = fetch_taxon_counts(pipeline_runs, count_type, page_size)
      timer_by_count_type.split("all_fetch")

      # get background for all tax ids chosen
      tax_ids = all_taxa.uniq { |x| x[0] }
      timer_by_count_type.split("fetch_background-tax_ids")
      taxon_summaries = fetch_background_info(tax_ids, count_type)
      timer_by_count_type.split("fetch_background")
      # define the decision to proceed to get more data?
      #
      # how many extra taxa would be added if we continued?
      # per category, how many do we have per category? how many more can we load?

      all_taxa_per_pr = fetch_ordered_taxon_counts(pipeline_runs, count_type, page_size)
      timer_by_count_type.split("fetch_all_ordered_and_limited_within_pr")

      #
      # union is not performant enough
      #
      union = fetch_union(pipeline_runs, count_type, page_size)
      timer_by_count_type.split("fetch_all_with_union")

      timer_results_by_count_type[count_type] = timer_by_count_type.results
      taxon_counts_by_count_type[count_type] = {
        one: one_taxon.size,
        all: all_taxa.size,
        all_per_pr: all_taxa_per_pr.size,
        summaries: taxon_summaries.size,
        union: union.size,
      }
      tax_ids_by_count_type[count_type] = tax_ids
    end

    render json: {
      params: params,
      total_samples: samples.size,
      loaded_pipeline_runs: pipeline_runs.size,
      timer_results: {
        base: timer_base_results,
        by_count_type: timer_results_by_count_type,
      },
      taxon_counts: {
        base: {
          current: {
            nt: current_heatmap['nt'].values.map { |v| v["taxon_counts"].size }.inject(0, :+),
            nr: current_heatmap['nr'].values.map { |v| v["taxon_counts"].size }.inject(0, :+),
          },
        },
        by_count_type: taxon_counts_by_count_type,
      },
      sample_ids: samples.pluck(:id),
      tax_ids: tax_ids_by_count_type,
    }
  end

  private

  def fetch_taxon_counts(pipeline_runs, count_type, page_size)
    taxon_counts_query = TaxonCount
                         .where(
                           pipeline_run_id: pipeline_runs,
                           count_type: count_type || %w[NT NR],
                           tax_level: [TaxonCount::TAX_LEVEL_SPECIES, TaxonCount::TAX_LEVEL_GENUS]
                         )
                         .where.not(
                           tax_id: [
                             TaxonLineage::BLACKLIST_GENUS_ID,
                             TaxonLineage::HOMO_SAPIENS_TAX_ID,
                           ].flatten
                         )
                         .order(count: :desc)
    taxon_counts_query = taxon_counts_query.limit(page_size) if page_size
    return taxon_counts_query.pluck(*TAXON_COUNTS_FIELDS_TO_PLUCK)
  end

  def fetch_union(pipeline_runs, count_type, page_size)
    queries = []
    pipeline_runs.pluck(:id).each do |pipeline_run_id|
      query = TaxonCount
              .where(
                pipeline_run_id: pipeline_run_id,
                count_type: count_type || %w[NT NR],
                tax_level: [TaxonCount::TAX_LEVEL_SPECIES, TaxonCount::TAX_LEVEL_GENUS]
              )
              .where.not(
                tax_id: [
                  TaxonLineage::BLACKLIST_GENUS_ID,
                  TaxonLineage::HOMO_SAPIENS_TAX_ID,
                ].flatten
              )
              .order(count: :desc)
      query = query.limit(page_size) if page_size
      queries << query.to_sql
    end
    query_result = ActiveRecord::Base.connection.select_all("(#{queries.join(') UNION ALL (')})")
    return query_result.rows
  end

  def fetch_ordered_taxon_counts(pipeline_runs, count_type, top_n)
    raw_sql_query = ActiveRecord::Base.send(:sanitize_sql_array, [
                                              "SELECT tax_id, pid, count
                                                FROM (
                                                  SELECT tc.tax_id, tc.pipeline_run_id AS pid, tc.count, @pr_rank := IF(@current_pr = tc.pipeline_run_id, @pr_rank + 1, 1) AS pr_rank, @current_pr := tc.pipeline_run_id
                                                  FROM taxon_counts tc
                                                  WHERE
                                                  tc.pipeline_run_id IN (?)
                                                  AND tc.count_type = ?
                                                  ORDER BY tc.pipeline_run_id, tc.count DESC
                                                ) ranked
                                                WHERE pr_rank <= ?",
                                              pipeline_runs.pluck(:id),
                                              count_type,
                                              top_n,
                                            ])
    query_result = ActiveRecord::Base.connection.select_all(raw_sql_query)
    return query_result.rows
  end

  def fetch_background_info(tax_ids, count_type)
    taxon_summaries = TaxonSummary
                      .where(
                        background_id: DEFAULT_BACKGROUND_ID,
                        tax_id: tax_ids,
                        count_type: count_type || %w[NT NR]
                      )

    return taxon_summaries.pluck(*TAXON_SUMMARIES_FIELDS_TO_PLUCK)
  end
end
