# exprdb d3 plots

## Overview

The js code in this repo is for the d3 based plotting from the exprdb app. The main intention is
to allow developers to work with this code base without needing the rest of the app code.

## How to run

In order to run this js code, you need to copy it to a directory on your computer and open 
the index_xxx.html page of interest. However, due to cross origin requests (CORS) via js being blocked by 
all browsers, it is required to install a Chrome extension (see below for ModHeader instructions) in order 
to allow CORS and also to add the Authentication token to the HTTP request header so that the demo site 
will return data.

Alternatively, if you are developing offline and want to use the static output files from the
fixtures/ directory, then you won't need to use CORS requests, but you do need to allow Chrome to read local files
from javascript by starting Chrome with the --allow-file-access-from-files option. Or you can put 
the static files on a web server that you own.

### How to use the boxplot app

You can view different datasets (called "series") and also type in genes of interest. After selecting a new Series,
the "Group By" and "Color By" dropdowns choices get filled in depending on the Series you selected.  Every Series 
has any number of samples, typically ranging from 20 to several thousand. Each Sample within each Series has about
20,000 genes which have expression values.  Each Sample also has a collection of 5-20 different annotations (meta-data)
which is used to determine the group and color for each Gene in the Dataset.

Here are some example genes (you need to match the case provided - and for human data, usually genes are all CAPS):

* IL2
* CD8A
* FAP
* TNF
* IL6
* CDK2

When you enter in a new gene, you can hit your tab or enter key in order to do the ajax (d3.csv) call to get the 
new data.

### API calls

There are several main API calls used to get the data needed to render plots. They are reviewed here, along with 
the names of the example output files which are stored in the fixtures/ directory of this repo in order
to support offline development.

#### Get a list of all the different series

The first step when the js page loads is to get a list of all available series for the currently logged in user.
The API will get the series name, organism, and series_id in order to fill the first dropdown.

Here are some example calls to get all the series names which are available to this user. The first one 
(name_only=1) will get all available series and only show the most basic information for each series (like name,
description, organism). The second one (general_type=sample_coord) filters to show series which have sample coordinate 
data (this is useful for the scatter/singe cell layout)

    http://demo.needlegenomics.com/series_api/series/?name_only=1
    http://demo.needlegenomics.com/series_api/series/?name_only=1&general_type=sample_coord

Example file: _fixtures/series_api.series.json_

#### Get the "group by/color by" information for a particular series

This API will get sample annotations of all samples in a particular series (some Series have a handful of 
samples and other Series could have 1000s of samples). Each sample also has 2-20 different annotations which are 
used in order to figure out the group or color for that sample.  The group and color values are the same choices. 
Once a series is choosen in the drop-down, then this csv file is retrieved and it has all the meta-data information 
for all the samples, including the sample ids, sample names, sample coordinates, various columns which can be used 
for grouping and coloring, and potentially the tSNE or PCA coordinates. After this file is loaded,
then the column names of the csv file are added as choices to the Group by and Color by drop downs. The meta-data
for each sample is also saved so that the app can use this to determine the group and color for each point.

    http://demo.needlegenomics.com/series_api/series_data_view/37?sample_labels=1&transpose=1&debug=1

File: _fixtures/series_api.series_data_view.samples_labels.csv_

#### Get the gene expression information for a particular gene in a series

This API will get just the gene expression values for a single gene (name=Cd8a) and will not re-download all the
sample annotations (sample_labels=0). Alternatively, you can get the gene expression values and sample annotations
at the same time by settings sample_labels=1 and keeping name=Cd8a in there.  If needed, you can grab two different
gene expression values by separating the gene names with a comma.

    http://demo.needlegenomics.com/series_api/series_data_view/37?name=Cd8a&sample_labels=0&transpose=1&debug=1
    http://demo.needlegenomics.com/series_api/series_data_view/37?name=Cd8a&name=Cd8b&sample_labels=0&transpose=1&debug=1

Once a gene is typed into the Gene box (with the proper case), then this csv file is retrieved from the server. 
This has the expression value for the one gene of interest in every sample of the series/dataset.

File: _fixtures/series_api.series_data_view.samples_labels.TNF.csv_

#### Get scores

In the single cell viewer, if a user clicks on a cluster name, then a table of scores will appear. There are two API 
calls to get that information. The first one shows how to get a list of all scores which match that cluster name. 

##### Get a list of scores
Each row in the CSV output file (using the API call below) has a score which is focused on the particular cluster 
which was clicked. It requires the series_pk, annot_name (which is the "color by" selection) and the group (which
is the name of the cluster which was clicked). But, for the purpose of getting the scores which match the cluster,
just pick the top one in the csv output file (after the header row):

    http://demo.needlegenomics.com/series_api/score_view/?debug=1&series_pk=18&annot_name=cell_and_source&group=Treg_tumor&output_style=ordered
	
The final option "output_style=" should be "ordered" for the single cell viewer, but other options include "related" 
which will group the scores together if they have the same series_id/annot_name/group1/group2 variables. Removing 
the output_style option will list all the scores in a default order by series id and score id. Also note that the 
"ordered" option will add some extra info for each score: 

* the number of samples in each group, 
* the value of the 50th best ranking score, and
* a numeric "rating" column which can be used to sort the scores (higher is better)


##### Get the score data

Once you have the correct score_id, then use this API call to grab the "score data" in a CSV output where each row 
is a score. Put the score_id in the "expr_score_pk_1" param and then you can choose how many of the top scores to pick
by changing the threshold_1=50 to a different number:

    http://demo.needlegenomics.com/browse/advanced?&expr_score_pk_1=382&which_and_operator_1=rank_lte&threshold_1=50&show_related_expr_scores=on&debug=1&csv=1&simple_colnames=1
	
Another option will get the top 50 ranking score data for multiple scores, 
but won't fill in the score data for other scores even when score data exists for the features. 
I could change that behavior, but effort. So, I think the best plan for now is to use the first option.    

    http://demo.needlegenomics.com/series_api/score_data_view/?debug=1&score_pk_list=103,104&which=rank&operator=lt&threshold=50&wide=1

	
## Configuration of ModHeader by bewisse.com

Before loading the index_xxx.html page into your Chrome browser, you need to install an extension 
to allow CORS and add a Auth header: [ModHeader](https://chrome.google.com/webstore/detail/modheader/idgpnmonknjnojddfkpgkljpfnnfcklj)

You need to add a Request header with the Name of "Authorization" and the Value of "Token abcdefgh123456789" but don't
use abcdefg...., you will instead use a token provided by someone who has access to the 
[demo site](http://demo.needlegenomics.com).

You also need to add a Response Header with the "+" sign at the top of the configuration window. The Name for this one
is "Access-Control-Allow-Origin" and the Value is "*" (no quotes). 

The reviews seemed good for this extension, but you probably still want to pause or disable it when not doing
active development, or you can also "lock tab" so that it only is modifying headers on the exprdb index html tab.
