function rap = reproa_validateCONN(rap,command)
resp='';

switch command
    case 'doit'
        if hasStream(rap,'roiextract'), load(char(getFileByStream(rap,'subject',1,'roiextract')),'roiextract'); end % assume already validated rois -> load only the first one

        % find common ROI names
        ROIs = cell(1,getNByDomain(rap,'subject'));
        for subj = 1:getNByDomain(rap,'subject')
            load(char(getFileByStream(rap,'subject',subj,'settings')),'CONN_x');
            ROIs{subj} = CONN_x.Preproc.variables.names(lookFor(CONN_x.Preproc.variables.names,'Atlas'));
            if subj == 1
                commonROIs = ROIs{subj};
            else
                commonROIs = intersect(commonROIs,ROIs{subj});
            end
        end

        % ROI validation
        if exist('roiextract','var')
            validROIs = cellfun(@(r) sscanf(r,'Atlas.cluster%d'), commonROIs);
            [~,~,indConnectivity] = intersect([roiextract.ROIval],validROIs);
            commonROIs = commonROIs(indConnectivity);
        end

         % determine final indices
        indROIs = cell(1,getNByDomain(rap,'subject'));
        for subj = 1:getNByDomain(rap,'subject')
            [~, indROIs{subj}] = intersect(ROIs{subj},commonROIs);
        end

        % save valid ROI names
        fnROIs = fullfile(getPathByDomain(rap,'study',[]),'validROIs.txt');
        fid = fopen(fnROIs,'w'); cellfun(@(r) fprintf(fid,'%s\n',r), commonROIs); fclose(fid);
        putFileByStream(rap,'study',[],'roinames',fnROIs);

        % select CMs' rows and columns of valid ROIs
        for subj = 1:getNByDomain(rap,'subject')
            for run = rap.acqdetails.selectedruns
                fnRun = cellstr(getFileByStream(rap,'fmrirun',[subj run],'connectivity'));
                for f = 1:numel(fnRun)
                    load(fnRun{f},'runCM');
                    runCM = runCM(indROIs{subj},indROIs{subj});
                    save(fnRun{f},'runCM');
                end
                putFileByStream(rap,'fmrirun',[subj run],'connectivity',fnRun);
            end

            fnSubj = cellstr(getFileByStream(rap,'subject',subj,'connectivity'));
            for f = 1:numel(fnSubj)
                load(fnSubj{f},'subjectCM');
                subjectCM = subjectCM(indROIs{subj},indROIs{subj});
                save(fnSubj{f},'subjectCM');
            end
            putFileByStream(rap,'subject',subj,'connectivity',fnSubj);
        end
end
