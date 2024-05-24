function rap = reproa_CONN(rap,command,subj)
resp='';

switch command
    case 'doit'
        global reproacache
        CONN = reproacache('toolbox.conn');
        CONN.load;
        global CONN_x
        CONN_x.gui = struct('overwrite','yes'); % allow overwriting partial setups

        roiNames = {'GM' 'WM' 'CSF' 'Atlas'};

        CONNROOT = fullfile(getPathByDomain(rap,'subject',subj), 'conn');
        dirMake(CONNROOT);

        % Setup
        if hasStream(rap,'subject',subj,'structural'), fnAnat = char(getFileByStream(rap,'subject',subj,'structural'));
        else, fnAnat = '';
        end
        fnFunc = getFileByStream(rap,'subject',subj,'fmri');
        if hasStream(rap,'subject',subj,'segmentationmasks')
            seg = getFileByStream(rap,'subject',subj,'segmentationmasks');
            for r = 1:3, fnROIs.(roiNames{r}) = char(seg.(roiNames{r})); end
        else
            for r = 1:3, fnROIs.(roiNames{r}) = ''; end
        end
        fnROIs.(roiNames{4}) = char(getFileByStream(rap,'subject',subj,'rois'));
        if hasStream(rap,'subject',subj,'firstlevel_spm')
            fnSPM = char(getFileByStream(rap,'subject',subj,'firstlevel_spm'));
        else
            fnSPM = '';
        end

        analyses = getSetting(rap,'analysis');
        nRun = getNByDomain(rap,'fmrirun',subj);

        % Heuristics
        processNameSfx = '';
        if ~isempty(fnROIs.Atlas)
            Y = spm_read_vols(spm_vol(fnROIs.Atlas));
            multiROI = sum(unique(Y)~=0)>1;
            ROIonly = all(cellfun(@isempty, {analyses.roival}));
            doPPI = ~cellfun(@isempty, {analyses.condition});
        else
            multiROI = false;
            ROIonly = false;
            doPPI = false;
        end
        if ROIonly, processNameSfx = '_roi'; end

        % Initialize
        CONN_x.Setup.analysisunits = 2; % 1 = PSC, 2 = raw
        CONN_x.Setup.outputfiles = [0 0 0 0 0 0];

        CONN_x.filename = fullfile(CONNROOT);
        CONN_x.folders.data = fullfile(CONN_x.filename,'data');
        CONN_x.folders.preprocessing = fullfile(CONN_x.filename,'preprocessing');
        CONN_x.folders.qa = fullfile(CONN_x.filename,'preprocessing','qa');
        CONN_x.folders.bookmarks = fullfile(CONN_x.filename,'results','bookmarks');
        CONN_x.folders.firstlevel = fullfile(CONN_x.filename,'results','firstlevel');
        CONN_x.folders.firstlevel_vv = fullfile(CONN_x.filename,'results','firstlevel_vv');
        CONN_x.folders.firstlevel_dyn = fullfile(CONN_x.filename,'results','firstlevel_dyn');
        CONN_x.folders.secondlevel = fullfile(CONN_x.filename,'results','secondlevel');
        dirMake(CONN_x.folders.data);
        dirMake(CONN_x.folders.preprocessing);

        % Data
        if ~isempty(fnAnat)
            logging.info('%s: structural found',mfilename);
            CONN_x.Setup.structural{1} = repmat({conn_file(fnAnat)},1,nRun);
            CONN_x.Setup.structural_sessionspecific = 1;
        end
        for r = 1:nRun
            conn_set_functional(1,r,[],fnFunc{r});
        end
        CONN_x.Setup.functional = {cellfun(@conn_file, fnFunc, 'UniformOutput', false)};
        CONN_x.Setup.rois.files{1} = {};
        for r = roiNames
            if ~isempty(fnROIs.(r{1}))
                logging.info('%s: %s mask found',mfilename,r{1});
                CONN_x.Setup.rois.names(end+1) = r;
                CONN_x.Setup.rois.files{1}{end+1} = repmat({conn_file(fnROIs.(r{1}))},1,nRun);
            end
        end
        CONN_x.Setup.rois.names(end+1) = {''};
        nROIs = numel(CONN_x.Setup.rois.names)-1;
        CONN_x.Setup.rois.dimensions = repmat({1},1,nROIs);
        [~, indTissue] = intersect(CONN_x.Setup.rois.names,{'WM' 'CSF'});
        CONN_x.Setup.rois.dimensions(indTissue) = {1};
        CONN_x.Setup.rois.mask = false(1,nROIs);
        CONN_x.Setup.rois.subjectspecific = true(1,nROIs);
        CONN_x.Setup.rois.sessionspecific = true(1,nROIs);
        CONN_x.Setup.rois.multiplelabels = false(1,nROIs);
        CONN_x.Setup.rois.multiplelabels(strcmp(CONN_x.Setup.rois.names,'Atlas')) = multiROI;
        CONN_x.Setup.rois.regresscovariates = false(1,nROIs);
        CONN_x.Setup.rois.regresscovariates(indTissue) = true;
        CONN_x.Setup.rois.unsmoothedvolumes = true(1,nROIs);
        CONN_x.Setup.rois.weighted = false(1,nROIs);
        if ~isempty(fnSPM)
            logging.info('%s: SPM found',mfilename);
            conn_importspm(fnSPM,...
                'addfunctional',false,...
                'addconditions',true,...
                'breakconditionsbysession',true,...
                'addrestcondition',false,...
                'keeppreviousconditions',false,...
                'addcovariates',true,...
                'addrealignment',false,...
                'addartfiles',false);
        else
            logging.info('%s: No SPM found -> resting-state fMRI assumed',mfilename);
            CONN_x.Setup.conditions.model{1} = [];
            CONN_x.Setup.conditions.param(1) = 0;
            CONN_x.Setup.conditions.filter{1} = [];
            CONN_x.Setup.conditions.names{1} = 'rest';
            for r = 1:nRun
                CONN_x.Setup.conditions.values{1}{1}{r}{1} = 0;
                CONN_x.Setup.conditions.values{1}{1}{r}{2} = inf;
            end
            CONN_x.Setup.conditions.names{2} = ' ';
        end
        conn_process(['setup' processNameSfx]);

        % Denoising
        CONN_x.filename = fullfile(CONNROOT);
        [~,indConf] = intersect(CONN_x.Preproc.variables.names, getSetting(rap,'denoising.confounds'));
        indConf = sort(indConf);
        CONN_x.Preproc.confounds.names = CONN_x.Preproc.variables.names(indConf);
        CONN_x.Preproc.confounds.filter = repmat({0},1,numel(CONN_x.Preproc.confounds.names));
        CONN_x.Preproc.confounds.types = {};
        CONN_x.Preproc.confounds.power = {};
        CONN_x.Preproc.confounds.deriv = {};
        CONN_x.Preproc.confounds.dimensions = {};

        CONN_x.Preproc.filter = getSetting(rap,'denoising.filter');
        if isnan(CONN_x.Preproc.filter(1))
            inStream = getStreamByName(rap,'firstlevel_spm');
            if isempty(inStream.path) % local
                inrap = rap;
            else % remote
                dat = load(fullfile(inStream.path,'rap.mat'));
                inrap = setCurrentTask(dat.rap,'task',inStream.taskindex);
            end
            CONN_x.Preproc.filter(1) = ...
                1/getSetting(setSourceTask(inrap,'reproa_firstlevelmodel'),'highpassfilter');
        end
        CONN_x.Preproc.regbp = 2; % 1 = filter, then regress, 2 = Simultaneous regression and filtering
        CONN_x.Preproc.detrending = 1;
        conn_process(['denoising' processNameSfx]);

        % Setup analyses
        for a = 1:numel(analyses)
            CONN_x.Analyses(a).name = analyses(a).name;
            CONN_x.Analyses(a).conditions = intersect(CONN_x.Setup.conditions.names,analyses(a).condition);
            if ~isempty(analyses(a).roival)
                CONN_x.Analyses(a).regressors.names = intersect(CONN_x.Analysis_variables.names,...
                                                                arrayfun(@(r) sprintf('%s.cluster%03d','Atlas',r), ...
                                                                         analyses(a).roival, 'UniformOutput', false));
            else
                CONN_x.Analyses(a).regressors.names = ...
                    CONN_x.Analysis_variables.names(lookFor(CONN_x.Analysis_variables.names,'Atlas'));
            end
            CONN_x.Analyses(a).regressors.dimensions = {};
            CONN_x.Analyses(a).regressors.deriv = {};
            CONN_x.Analyses(a).regressors.fbands = {};
        end
        conn_process('analyses_seedsetup');

        % Run analyses
        [~,~,attr] = getSetting(rap,'analysis.measure'); optMeasure = attr.options;
        [~,~,attr] = getSetting(rap,'analysis.weight'); optWeight = attr.options;
        CONN_x.gui = []; % avoid overwriting existing results
        for a = 1:numel(analyses)
            if numel(CONN_x.Analyses(a).regressors.names) == 1 % 'Seed-to-Voxel'
                CONN_x.Analyses(a).type = 2;
            else % 'ROI-to-ROI'
                CONN_x.Analyses(a).type = 1;
            end
            CONN_x.Analyses(a).measure = find(strcmp(strsplit(optMeasure,'|'),analyses(a).measure));
            CONN_x.Analyses(a).modulation = doPPI(a);
            CONN_x.Analyses(a).weight = find(strcmp(strsplit(optWeight,'|'),analyses(a).weight));
            [~,indCond] = intersect(CONN_x.Setup.conditions.allnames,CONN_x.Analyses(a).conditions);
            CONN_x.gui.conditions = indCond';
            conn_process('analyses_gui_seedandroi',a)
        end

        save([CONNROOT '.mat'],'CONN_x');
        putFileByStream(rap,'subject',subj,'settings',[CONNROOT '.mat']);

        % Results/summary
        fnOutRun = repmat({{}},1,nRun); fnOutSubj = {};
        for a = 1:numel(CONN_x.Analyses)
            CONN_x.Results(1).name = CONN_x.Analyses(a).name;
            CONN_x.Results.foldername = fullfile(CONN_x.Results.name);
            CONN_x.Results.display = 0;
            CONN_x.Results.xX.nsubjecteffects = 1;
            CONN_x.Results.xX.csubjecteffects = 1;
            CONN_x.Results.xX.nsubjecteffectsbyname = {'AllSubjects'};
            [~, indCond] = intersect(CONN_x.Setup.conditions.allnames,CONN_x.Analyses(a).conditions);
            CONN_x.Results.xX.nconditions = indCond;
            CONN_x.Results.xX.cconditions = ones(1,numel(CONN_x.Analyses(a).conditions));
            CONN_x.Results.xX.nconditionsbyname = CONN_x.Analyses(a).conditions;
%             CONN_x.Results.xX.modeltype = 2; % 1 = RFX, 2 = FFX - not working!
            CONN_x.Analysis = a;
            conn_process(['results' processNameSfx]);

            % Runs
            for c = 1:numel(CONN_x.Results.xX.nconditions)
                runCM = zeros(numel(CONN_x.Analyses(a).sources),numel(CONN_x.Analyses(a).sources),1);
                fn = fullfile(CONN_x.folders.firstlevel,...
                              CONN_x.Analyses(a).name,...
                              sprintf('resultsROI_Condition%03d.mat',CONN_x.Results.xX.nconditions(c)));
                load(fn,'Z');
                runCM(:,:,1) = Z;
                run = str2double(regexp(CONN_x.Results.xX.nconditionsbyname{c},'(?<=run)[0-9]','match'));
                if isempty(run), run = 1; end
                fnOutRun{run}(end+1) = cellstr(spm_file(fullfile(getPathByDomain(rap,'fmrirun',[subj run]),...
                                                                  CONN_x.Analyses(a).name),'ext','mat'));
                save(fnOutRun{run}{end},'runCM');
            end
            % Subject
            load(fullfile(CONN_x.folders.secondlevel,CONN_x.Analyses(a).name,'ROI.mat'),'ROI');
            subjectCM = vertcat(ROI.h);
            fnOutSubj(end+1) = cellstr(spm_file(fullfile(getPathByDomain(rap,'subject',subj),CONN_x.Analyses(a).name),'ext','mat'));
            save(fnOutSubj{end},'subjectCM');
        end
        for run = rap.acqdetails.selectedruns
            putFileByStream(rap,'fmrirun',[subj run],'connectivity',fnOutRun{run});
        end
        putFileByStream(rap,'subject',subj,'connectivity',fnOutSubj);

        CONN.unload;

end
