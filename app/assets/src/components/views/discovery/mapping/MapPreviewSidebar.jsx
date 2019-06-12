import cx from "classnames";
import { difference, find, isEmpty, union } from "lodash/fp";
import React from "react";

import { logAnalyticsEvent } from "~/api/analytics";
import Tabs from "~/components/ui/controls/Tabs";
import PropTypes from "~/components/utils/propTypes";
import DiscoverySidebar from "~/components/views/discovery/DiscoverySidebar";
import TableRenderers from "~/components/views/discovery/TableRenderers";
import InfiniteTable from "~/components/visualizations/table/InfiniteTable";

import cs from "./map_preview_sidebar.scss";

export default class MapPreviewSidebar extends React.Component {
  constructor(props) {
    super(props);

    const { initialSelectedSampleIds } = this.props;

    this.state = {
      selectedSampleIds: initialSelectedSampleIds || new Set()
    };

    this.columns = [
      {
        dataKey: "sample",
        flexGrow: 1,
        width: 150,
        cellRenderer: cellData => TableRenderers.renderSample(cellData, false),
        headerClassName: cs.sampleHeader
      },
      {
        dataKey: "createdAt",
        label: "Uploaded On",
        className: cs.basicCell,
        cellRenderer: TableRenderers.renderDateWithElapsed
      },
      {
        dataKey: "host",
        flexGrow: 1,
        className: cs.basicCell
      },
      // If you already have access to Maps, just see Location V2 here.
      {
        dataKey: "collectionLocationV2",
        label: "Location",
        flexGrow: 1,
        className: cs.basicCell
      },
      {
        dataKey: "totalReads",
        label: "Total Reads",
        flexGrow: 1,
        className: cs.basicCell,
        cellDataGetter: ({ dataKey, rowData }) =>
          TableRenderers.formatNumberWithCommas(rowData[dataKey])
      },
      {
        dataKey: "nonHostReads",
        label: "Passed Filters",
        flexGrow: 1,
        className: cs.basicCell,
        cellRenderer: TableRenderers.renderNumberAndPercentage
      },
      {
        dataKey: "qcPercent",
        label: "Passed QC",
        flexGrow: 1,
        className: cs.basicCell,
        cellDataGetter: ({ dataKey, rowData }) =>
          TableRenderers.formatPercentage(rowData[dataKey])
      },
      {
        dataKey: "duplicateCompressionRatio",
        label: "DCR",
        flexGrow: 1,
        className: cs.basicCell,
        cellDataGetter: ({ dataKey, rowData }) =>
          TableRenderers.formatPercentage(rowData[dataKey])
      },
      {
        dataKey: "erccReads",
        label: "ERCC Reads",
        flexGrow: 1,
        className: cs.basicCell,
        cellDataGetter: ({ dataKey, rowData }) =>
          TableRenderers.formatNumberWithCommas(rowData[dataKey])
      },
      {
        dataKey: "notes",
        flexGrow: 1,
        className: cs.basicCell
      },
      {
        dataKey: "nucleotideType",
        label: "Nucleotide Type",
        flexGrow: 1,
        className: cs.basicCell
      },
      {
        dataKey: "sampleType",
        label: "Sample Type",
        flexGrow: 1,
        className: cs.basicCell
      },
      {
        dataKey: "subsampledFraction",
        label: "SubSampled Fraction",
        flexGrow: 1,
        className: cs.basicCell,
        cellDataGetter: ({ dataKey, rowData }) =>
          TableRenderers.formatNumber(rowData[dataKey])
      },
      {
        dataKey: "totalRuntime",
        label: "Total Runtime",
        flexGrow: 1,
        className: cs.basicCell,
        cellDataGetter: ({ dataKey, rowData }) =>
          TableRenderers.formatDuration(rowData[dataKey])
      }
    ];
  }

  handleLoadSampleRows = async () => {
    // TODO(jsheu): Add pagination on the endpoint and loading for long lists of samples
    const { samples } = this.props;
    return samples;
  };

  handleSelectRow = (value, checked) => {
    const { selectedSampleIds } = this.state;

    let newSelected = selectedSampleIds;
    if (checked) {
      newSelected.add(value);
    } else {
      newSelected.delete(value);
    }
    this.setSelectedSampleIds(newSelected);

    logAnalyticsEvent("MapPreviewSidebar_row_selected", {
      selectedSampleIds: newSelected.length
    });
  };

  handleRowClick = ({ event, rowData }) => {
    const { onSampleClicked, samples } = this.props;
    const sample = find({ id: rowData.id }, samples);
    onSampleClicked && onSampleClicked({ sample, currentEvent: event });
    logAnalyticsEvent("MapPreviewSidebar_row_clicked", {
      sampleId: sample.id,
      sampleName: sample.name
    });
  };

  isSelectAllChecked = () => {
    const { selectableIds } = this.props;
    const { selectedSampleIds } = this.state;
    return (
      !isEmpty(selectableIds) &&
      isEmpty(difference(selectableIds, Array.from(selectedSampleIds)))
    );
  };

  handleSelectAllRows = (value, checked) => {
    const { selectableIds } = this.props;
    const { selectedSampleIds } = this.state;
    let newSelected = new Set(
      checked
        ? union(selectedSampleIds, selectableIds)
        : difference(selectedSampleIds, selectableIds)
    );
    this.setSelectedSampleIds(newSelected);

    logAnalyticsEvent("MapPreviewSidebar_select-all-rows_clicked");
  };

  setSelectedSampleIds = selectedSampleIds => {
    const { onSelectionUpdate } = this.props;
    this.setState({ selectedSampleIds });
    onSelectionUpdate && onSelectionUpdate(selectedSampleIds);
  };

  computeTabs = () => {
    const { samples } = this.props;
    return [
      {
        label: "Summary",
        value: "Summary"
      },
      {
        label: (
          <div>
            <span className={cs.tabLabel}>Samples</span>
            {samples.length > 0 && (
              <span className={cs.tabCounter}>{samples.length}</span>
            )}
          </div>
        ),
        value: "Samples"
      }
    ];
  };

  reset = () => {
    this.infiniteTable && this.infiniteTable.reset();
    this.setSelectedSampleIds(new Set());
  };

  renderTable = () => {
    const { activeColumns, protectedColumns } = this.props;
    const { selectedSampleIds } = this.state;

    const rowHeight = 60;
    const batchSize = 1e4;
    const selectAllChecked = this.isSelectAllChecked();
    return (
      <div className={cs.container}>
        <div className={cs.table}>
          <InfiniteTable
            columns={this.columns}
            defaultRowHeight={rowHeight}
            initialActiveColumns={activeColumns}
            minimumBatchSize={batchSize}
            onLoadRows={this.handleLoadSampleRows}
            onRowClick={this.handleRowClick}
            onSelectAllRows={this.handleSelectAllRows}
            onSelectRow={this.handleSelectRow}
            protectedColumns={protectedColumns}
            ref={infiniteTable => (this.infiniteTable = infiniteTable)}
            rowClassName={cs.tableDataRow}
            rowCount={batchSize}
            selectableKey="id"
            selectAllChecked={selectAllChecked}
            selected={selectedSampleIds}
            threshold={batchSize}
          />
        </div>
      </div>
    );
  };

  renderNoData = () => {
    return (
      <div className={cs.noData}>Select a location to preview samples.</div>
    );
  };

  renderSummaryTab = () => {
    const {
      allowedFeatures,
      discoveryCurrentTab,
      loading,
      projectDimensions,
      projectStats,
      sampleDimensions,
      sampleStats
    } = this.props;

    return (
      <DiscoverySidebar
        allowedFeatures={allowedFeatures}
        className={cs.summaryInfo}
        currentTab={discoveryCurrentTab}
        loading={loading}
        projectDimensions={projectDimensions}
        projectStats={projectStats}
        sampleDimensions={sampleDimensions}
        sampleStats={sampleStats}
      />
    );
  };

  renderSamplesTab = () => {
    const { samples } = this.props;
    return samples.length === 0 ? this.renderNoData() : this.renderTable();
  };

  render() {
    const { className, currentTab, onTabChange } = this.props;
    return (
      <div className={cx(className, cs.sidebar)}>
        <Tabs
          className={cs.tabs}
          hideBorder
          onChange={onTabChange}
          tabs={this.computeTabs()}
          value={currentTab}
        />
        {currentTab === "Summary"
          ? this.renderSummaryTab()
          : this.renderSamplesTab()}
      </div>
    );
  }
}

MapPreviewSidebar.defaultProps = {
  activeColumns: ["sample"],
  protectedColumns: ["sample"],
  currentTab: "Summary"
};

MapPreviewSidebar.propTypes = {
  activeColumns: PropTypes.array,
  allowedFeatures: PropTypes.arrayOf(PropTypes.string),
  className: PropTypes.string,
  currentTab: PropTypes.string,
  discoveryCurrentTab: PropTypes.string,
  initialSelectedSampleIds: PropTypes.instanceOf(Set),
  loading: PropTypes.bool,
  onSampleClicked: PropTypes.func,
  onSelectionUpdate: PropTypes.func,
  onTabChange: PropTypes.func,
  projectDimensions: PropTypes.array,
  projectStats: PropTypes.object,
  protectedColumns: PropTypes.array,
  sampleDimensions: PropTypes.array,
  samples: PropTypes.array,
  sampleStats: PropTypes.object,
  selectableIds: PropTypes.array.isRequired
};