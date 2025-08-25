export const en = {
  hello: {
    title: 'Hello {name}',
    name: 'Name',
  },
} as const;

export type LanguageStruct<T> = {
  [K in keyof T]: T[K] extends object ? LanguageStruct<T[K]> : string;
};

export type LangStruct = LanguageStruct<typeof en>;
