import { keyBy, mapValues } from "lodash";
import { unionBy } from "lodash/fp";

// Transform the server metadata response to a simple key => value map.
export const processMetadata = metadata => {
  let newMetadata = keyBy(metadata, "key");

  newMetadata = mapValues(
    newMetadata,
    val =>
      val.data_type === "string"
        ? val.text_validated_value
        : val.number_validated_value
  );

  return newMetadata;
};

export const processMetadataTypes = metadataTypes =>
  keyBy(metadataTypes, "key");

export const extractMetadataTypesByHostGenomes = (
  metadataTypesByHostGenomeName,
  hostGenomeNames
) => {
  let metadataTypes = [];

  hostGenomeNames.forEach(name => {
    metadataTypes = unionBy(
      "key",
      metadataTypes,
      metadataTypesByHostGenomeName[name]
    );
  });

  return metadataTypes;
};