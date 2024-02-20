function test_conn_rest_connect(rap)
    rap.acqdetails.input.remoteworkflow(1) = struct(...
       'host','',...
       'path',fullfile(rap.acqdetails.root,'test_fmrirest'),...
       'allowcache',0,...
       'maxtask',''...
       );
    rap = reproaConnect(rap,'subjects','*','runs','*');

    rap = addFile(rap,'study',[],'rois',...
                  ['https://raw.githubusercontent.com/ThomasYeoLab/CBIG/master/stable_projects/'...
                  'brain_parcellation/Schaefer2018_LocalGlobal/Parcellations/MNI/'...
                  'Schaefer2018_100Parcels_7Networks_order_FSLMNI152_1mm.nii.gz']);
    rap.tasksettings.reproa_addfile.uncompress = 1;

    rap = renameStream(rap,'reproa_denormtofmri_rois_00001','input',...
                       'meanfmri_native','reproa_eddy_fmri_00001.meanfmri');
    rap.tasksettings.reproa_denormtofmri_rois.interp = 0;

    rap = renameStream(rap,'reproa_CONN_00001','input',...
                       'fmri','fmri.partial~files');

    rap.tasksettings.reproa_CONN.units = 'raw';
    rap.tasksettings.reproa_CONN.denoising.confounds = {'WM'};
    rap.tasksettings.reproa_CONN.denoising.filter = [0.01 0.1];

    rap.tasksettings.reproa_CONN.analysis.name = 'fconn';
    rap.tasksettings.reproa_CONN.analysis.condition = {'rest'}; % implicitly created; for multiple runs add _run<run number>
    rap.tasksettings.reproa_CONN.analysis.measure = 'correlation (bivariate)';
    rap.tasksettings.reproa_CONN.analysis.weight = 'none';

    processWorkflow(rap);

    reportWorkflow(rap);
end
