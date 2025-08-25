import React, {
  createContext,
  useContext,
  useState,
  ReactNode,
  useMemo,
  Fragment,
} from 'react';
import { languages, EnFlattenParams } from '../index';

type LanguageCode = keyof typeof languages;

interface Props {
  children: ReactNode;
  language?: LanguageCode;
}

type Params = Record<string, string | number | ReactNode>;

type EnKey = EnFlattenParams['key'];
type EnParams<K extends EnKey> = Extract<
  EnFlattenParams,
  { key: K }
>['params'] extends never
  ? undefined
  : Record<
      Extract<EnFlattenParams, { key: K }>['params'],
      string | number | ReactNode
    >;

type TranslateFunc = {
  <K extends EnKey>(key: K, params?: EnParams<K>): ReactNode;
  change: (lang: LanguageCode) => void;
};

function format(str: string, params?: Params): ReactNode {
  if (!params) return str;
  const parts: ReactNode[] = [];
  let lastIndex = 0;
  const regex = /\{(\w+)\}/g;
  let match: RegExpExecArray | null;
  while ((match = regex.exec(str))) {
    const [placeholder, key] = match;
    const index = match.index;
    if (lastIndex < index) parts.push(str.slice(lastIndex, index));
    parts.push(params[key as string] ?? placeholder);
    lastIndex = index + placeholder.length;
  }
  if (lastIndex < str.length) parts.push(str.slice(lastIndex));
  return parts.length > 1
    ? parts.map((e, i) => <Fragment key={i}>{e}</Fragment>)
    : str;
}

const TranslateContext = createContext<TranslateFunc>(
  Object.assign((key: string) => key, {
    change: () => {},
    language: 'en',
  }),
);

export const LanguageProvider = ({ children, language = 'en' }: Props) => {
  const [currentLanguage, setCurrentLanguage] =
    useState<LanguageCode>(language);

  const t = useMemo(() => {
    const fn = (<K extends EnKey>(key: K, params?: EnParams<K>) => {
      const template = languages[currentLanguage][key] || key;
      return format(template, params);
    }) as TranslateFunc;
    fn.change = (lang: LanguageCode) => setCurrentLanguage(lang);
    return fn;
  }, [currentLanguage]);

  return (
    <TranslateContext.Provider value={t}>{children}</TranslateContext.Provider>
  );
};

export const useTranslate = () => useContext(TranslateContext);
