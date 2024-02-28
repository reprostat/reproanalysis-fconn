function test_conn_task_connect(rap)
% This test script requires the previous execution of the script test_fmritask.m with the corresponding task list SPM_CH30.xml

    rap.acqdetails.input.remoteworkflow(1) = struct(...
       'host','',...
       'path',fullfile(rap.acqdetails.root,'test_fmritask'),...
       'allowcache',0,...
       'maxtask',''...
       );
    rap = reproaConnect(rap,'subjects','*','runs','*');

    rap = addFile(rap,'study',[],'rois',...
                  ['https://raw.githubusercontent.com/ThomasYeoLab/CBIG/master/stable_projects/'...
                  'brain_parcellation/Schaefer2018_LocalGlobal/Parcellations/MNI/'...
                  'Schaefer2018_100Parcels_7Networks_order_FSLMNI152_1mm.nii.gz']);
    rap.tasksettings.reproa_addfile.uncompress = 1;

    rap = renameStream(rap,'reproa_mask_segmentations_00001','input','reference','meanfmri');
    rap = renameStream(rap,'reproa_mask_segmentations_00001','input','segmentations','native_segmentations');
    rap.tasksettings.reproa_mask_segmentations.threshold = 'exclusive';

    rap.tasksettings.reproa_denormtofmri_rois.interp = 0;

    rap = renameStream(rap,'reproa_CONN_00001','input',...
                       'fmri','reproa_coregextended_00001.fmri');

    rap.tasksettings.reproa_CONN.units = 'raw';
    rap.tasksettings.reproa_CONN.denoising.confounds = {'WM'};
    rap.tasksettings.reproa_CONN.denoising.filter = [NaN 0.1];

    rap.tasksettings.reproa_CONN.analysis.name = 'fconn';
    rap.tasksettings.reproa_CONN.analysis.condition = {'listening_Session1'};
    rap.tasksettings.reproa_CONN.analysis.measure = 'regression (bivariate)';
    rap.tasksettings.reproa_CONN.analysis.weight = 'none';

    processWorkflow(rap);

    reportWorkflow(rap);
end
