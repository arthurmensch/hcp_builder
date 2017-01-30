import os
import traceback
from os.path import join


from hcp_builder.utils.nifti import monkey_patch_nifti_image

monkey_patch_nifti_image()

from hcp_builder.dataset import fetch_single_subject,\
    get_subject_list, TASK_LIST
from sklearn.externals.joblib import Parallel
from sklearn.externals.joblib import delayed

from hcp_builder.glm import run_glm
from hcp_builder.utils import configure, get_data_dirs


def download_and_make_contrasts(subject, task, overwrite=False, verbose=0):
    data_dir = get_data_dirs()[0]
    error_dir = join(data_dir, 'glm', 'failures')
    try:
        fetch_single_subject(subject, data_type='task',
                             tasks=task, overwrite=overwrite,
                             verbose=verbose)
    except Exception as e:
        print('Failed downloading subject %s for task %s' % (subject, task))
        traceback.print_exc()
        with open(join(error_dir, '%s_%s' % (subject, task)), 'w+') as f:
            f.write('Failed downloading.')
    try:
        run_glm(subject, task, backend='nistats', verbose=verbose)
    except Exception as e:
        print('Failed making contrasts for task %s, subject %s ' % (task, subject))
        traceback.print_exc()
        with open(join(error_dir, '%s_%s' % (subject, task)), 'w+') as f:
            f.write('Failed making contrasts.')


def restart_failed():
    configure()
    data_dir = get_data_dirs()[0]
    error_dir = join(data_dir, 'glm', 'failures')
    restarts = []
    n_jobs = 10
    for name in os.listdir(error_dir):
        os.unlink(join(error_dir, name))
        subject, task = name.split('_')
        restarts.append((subject, task))
    Parallel(n_jobs=n_jobs, verbose=10)(delayed(
        download_and_make_contrasts)(subject, task, verbose=1,
                                     overwrite=True) for subject, task
                                        in restarts)
def download():
    configure()
    data_dir = get_data_dirs()[0]
    error_dir = join(data_dir, 'glm', 'failures')
    if not os.path.exists(error_dir):
        os.makedirs(error_dir)
    n_jobs = 36
    subjects = get_subject_list()
    tasks = TASK_LIST
    Parallel(n_jobs=n_jobs, verbose=10)(delayed(
        download_and_make_contrasts)(subject, task, verbose=1) for subject in subjects
                                        for task in tasks)

if __name__ == '__main__':
    restart_failed()