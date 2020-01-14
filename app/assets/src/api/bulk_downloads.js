import { get, postWithCSRF } from "./core";

export const createBulkDownload = bulkDownload =>
  postWithCSRF("/bulk_downloads", {
    download_type: bulkDownload.downloadType,
    sample_ids: bulkDownload.sampleIds,
    params: bulkDownload.fields,
  });

export const getBulkDownload = bulkDownloadId =>
  get(`/bulk_downloads/${bulkDownloadId}.json`);

export const getBulkDownloads = () => get("/bulk_downloads.json");

export const getBulkDownloadTypes = () => get("/bulk_downloads/types");

export const getPresignedOutputUrl = bulkDownloadId =>
  get(`/bulk_downloads/${bulkDownloadId}/presigned_output_url`);

export const getValidSampleIdsForBulkDownload = bulkDownload =>
  postWithCSRF("/bulk_downloads", {
    sample_ids: bulkDownload.sampleIds,
  });
