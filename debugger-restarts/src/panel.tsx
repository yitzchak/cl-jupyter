import { ReactWidget } from '@jupyterlab/apputils';

import { PanelWithToolbar } from '@jupyterlab/ui-components';

import React, { useEffect, useState } from 'react';

import { IRestart, IRestartsModel } from './tokens';


class RestartsBody extends ReactWidget {
  constructor(model: IRestartsModel) {
    super();
    this._model = model;
    this.addClass('jp-DebuggerRestarts-body');
  }

  render(): JSX.Element {
    return <RestartsComponent model={this._model} />;
  }

  private _model: IRestartsModel;
}

const RestartsComponent = ({
  model
}: {
  model: IRestartsModel;
}): JSX.Element => {
  const [restarts, setRestarts] = useState(
    Array.from(model.restarts)
  );

  useEffect(() => {
    const updateRestarts = (
      _: IRestartsModel,
      updates: IRestart[]
    ): void => {
      setRestarts(Array.from(model.restarts));
    };

    /*const restoreRestarts = (_: IRestartsModel): void => {
      setRestarts(Array.from(model.restarts.entries()));
    };*/

    model.changed.connect(updateRestarts);
    //model.restored.connect(restoreRestarts);

    return (): void => {
      model.changed.disconnect(updateRestarts);
      //model.restored.disconnect(restoreRestarts);
    };
  });

  return (
    <table className={'jp-DebuggerRestarts-list'}>
      <tbody>
        {restarts.map((restart, index) => (
          <RestartComponent
            key={index}
            index={index}
            restart={restart}
            model={model}
          />
        ))}
      </tbody>
    </table>
  );
};


const RestartComponent = ({
  index,
  restart,
  model
}: {
  index: number;
  restart: IRestart;
  model: IRestartsModel;
}): JSX.Element => {
  return (
    <tr
      className={'jp-DebuggerRestart'}
      onClick={(): void => model.clicked.emit(index)}
      title={restart.text}
    >
      <td className={'jp-DebuggerRestart-name'}>{restart.name}</td>
      <td className={'jp-DebuggerRestart-text'}>{restart.text}</td>
    </tr>
  );
};


export class RestartsPanel extends PanelWithToolbar {
  constructor(options: any) {
    super(options);
    this.title.label = 'Restarts';
    const { model } = options;

    const body = new RestartsBody(model);

    this.addWidget(body);

    this.addClass('jp-DebuggerRestarts');
  }
}
