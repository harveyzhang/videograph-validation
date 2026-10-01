import { createRoot } from 'react-dom/client';
import { ReactFlowProvider } from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import './design/tokens.css';
import ProjectStudio from './project/ProjectStudio';

const rootEl = document.getElementById('root');
if (!rootEl) throw new Error('#root element missing in index.html');
createRoot(rootEl).render(
  <ReactFlowProvider>
    <ProjectStudio />
  </ReactFlowProvider>,
);
