import React from 'react';

interface TableProps {
  children: React.ReactNode;
  className?: string;
}

export const Table = ({ children, className = '' }: TableProps) => {
  return (
    <div className="overflow-x-auto">
      <table className={`min-w-full divide-y divide-gray-200 ${className}`}>
        {children}
      </table>
    </div>
  );
};

Table.Head = ({ children, className = '' }: TableProps) => (
  <thead className={`bg-gray-50 ${className}`}>
    {children}
  </thead>
);

Table.Body = ({ children, className = '' }: TableProps) => (
  <tbody className={`bg-white divide-y divide-gray-200 ${className}`}>
    {children}
  </tbody>
);

Table.Row = ({ children, className = '' }: TableProps) => (
  <tr className={`hover:bg-gray-50 ${className}`}>
    {children}
  </tr>
);

Table.Cell = ({ children, className = '' }: TableProps) => (
  <td className={`px-6 py-4 whitespace-nowrap text-sm text-gray-500 ${className}`}>
    {children}
  </td>
);

Table.Header = ({ children, className = '' }: TableProps) => (
  <th className={`px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider ${className}`}>
    {children}
  </th>
);